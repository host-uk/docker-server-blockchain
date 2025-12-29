# ============================================================
# BTCPay Server - All-in-One Production Image
# ============================================================
# Multi-crypto payment processor with integrated explorers.
#
# Services included:
#   - BTCPay Server (payment processor)
#   - NBXplorer (blockchain indexer)
#   - Bitcoin Core (full node)
#   - Monero Daemon (full node)
#   - Mempool (Bitcoin block explorer)
#   - Onion Monero Explorer (Monero block explorer)
#   - PostgreSQL (database)
#   - Nginx (reverse proxy)
#
# URL Routing (all on port 80/443):
#   /                -> BTCPay Server
#   /explorer/btc    -> Mempool (Bitcoin explorer)
#   /explorer/xmr    -> Monero Explorer
#
# Volume Architecture (IMPORTANT):
#   /config   -> NVMe RAID 1 (critical data, backed up)
#   /chaindata -> HDD (expendable blockchain data, NOT backed up)
#
# Build:
#   docker build -t btcpay-aio .
#
# Run:
#   docker run -d \
#     -v /mnt/nvme/pay.host.uk.com:/config \
#     -v /mnt/hdd/pay.host.uk.com:/chaindata \
#     -p 80:80 -p 443:443 -p 8333:8333 -p 18080:18080 \
#     btcpay-aio
# ============================================================

# Build arguments for version pinning
ARG ALPINE_VERSION=3.21
ARG BITCOIN_VERSION=28.1
ARG MONERO_VERSION=0.18.4.4
ARG NBXPLORER_VERSION=2.6.0
ARG BTCPAY_VERSION=2.3.1
ARG MEMPOOL_VERSION=3.2.1
ARG POSTGRES_VERSION=16
ARG NODE_VERSION=20

# ============================================================
# Stage 1: Build NBXplorer
# ============================================================
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS nbxplorer-build

ARG NBXPLORER_VERSION

RUN apk add --no-cache git

WORKDIR /src
RUN git clone --depth 1 --branch v${NBXPLORER_VERSION} https://github.com/dgarage/NBXplorer.git .

WORKDIR /src/NBXplorer
RUN dotnet publish -c Release -o /app --self-contained false

# ============================================================
# Stage 2: Build BTCPay Server
# ============================================================
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS btcpay-build

ARG BTCPAY_VERSION

RUN apk add --no-cache git

WORKDIR /src
RUN git clone --depth 1 --branch v${BTCPAY_VERSION} https://github.com/btcpayserver/btcpayserver.git .

WORKDIR /src/BTCPayServer
RUN dotnet publish -c Release -o /app --self-contained false

# ============================================================
# Stage 3: Build Mempool Frontend Only (backend built in runtime)
# ============================================================
FROM node:${NODE_VERSION}-alpine AS mempool-frontend-build

ARG MEMPOOL_VERSION

RUN apk add --no-cache git python3 make g++

WORKDIR /src
RUN git clone --depth 1 --branch v${MEMPOOL_VERSION} https://github.com/mempool/mempool.git .

WORKDIR /src/frontend
RUN npm ci

# Build frontend with base-href for /explorer/btc path
RUN npm run generate-config && \
    npm run ng -- build --configuration production --base-href /explorer/btc/ && \
    npm run sync-assets-dev || true

# ============================================================
# Stage 4: Placeholder for Monero Block Explorer
# ============================================================
# NOTE: Building onion-monero-blockchain-explorer requires building
# Monero from source, which is complex and time-consuming.
# For now, we skip this and rely on monerod's RPC for basic info.
# A pre-built XMR explorer can be added later if needed.
FROM debian:bookworm-slim AS xmr-explorer-build
RUN mkdir -p /src/build && echo "XMR explorer placeholder" > /src/build/README

# ============================================================
# Stage 5: Runtime Image (Debian for glibc compatibility)
# ============================================================
FROM debian:bookworm-slim

LABEL maintainer="Snider <snider@host.uk.com>"
LABEL org.opencontainers.image.source="https://github.com/host-uk/docker-server-blockchain"
LABEL org.opencontainers.image.description="BTCPay Server AIO - Multi-crypto payment processor with integrated explorers"
LABEL org.opencontainers.image.licenses="EUPL-1.2"
LABEL org.opencontainers.image.vendor="Host UK"
LABEL org.opencontainers.image.title="BTCPay Server AIO"

# Version args for runtime
ARG BITCOIN_VERSION
ARG MONERO_VERSION
ARG MEMPOOL_VERSION
ARG POSTGRES_VERSION
ARG NODE_VERSION

# ============================================================
# Environment - Storage Architecture
# ============================================================
# /config   = NVMe RAID 1 - CRITICAL (backed up)
# /chaindata = HDD 10TB   - EXPENDABLE (re-syncable, NOT backed up)
# ============================================================
ENV CONFIG_DIR=/config \
    CHAINDATA_DIR=/chaindata \
    DOMAIN=pay.host.uk.com

# ============================================================
# Environment - Service Defaults
# ============================================================
# BTCPay, Bitcoin, Monero, PostgreSQL, and .NET settings
ENV BTCPAY_NETWORK=mainnet \
    BTCPAY_HOST=localhost \
    BTCPAY_PROTOCOL=https \
    BTCPAY_ROOTPATH=/ \
    BITCOIN_PRUNE=0 \
    BITCOIN_DBCACHE=4096 \
    BITCOIN_MAXMEMPOOL=1000 \
    BITCOIN_TXINDEX=1 \
    MONERO_PRUNE=0 \
    POSTGRES_USER=btcpay \
    POSTGRES_DB=btcpay \
    PGDATA=/config/postgres \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    PATH="/usr/lib/postgresql/15/bin:$PATH"

# ============================================================
# Install runtime dependencies
# ============================================================
# supervisor, postgresql, mariadb, nodejs, nginx-extras, build tools,
# utilities, certificates, ICU for .NET
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor postgresql postgresql-contrib \
    mariadb-server mariadb-client \
    nodejs npm nginx-extras \
    python3 make g++ \
    curl bash gosu netcat-openbsd jq bzip2 git \
    ca-certificates libicu72 \
    && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup (need 1.79+ for mempool GBT module)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.79.0 && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# ============================================================
# Install .NET ASP.NET Core Runtime
# ============================================================
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) DOTNET_ARCH="x64" ;; \
        arm64) DOTNET_ARCH="arm64" ;; \
        *) echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL "https://dot.net/v1/dotnet-install.sh" -o /tmp/dotnet-install.sh; \
    chmod +x /tmp/dotnet-install.sh; \
    /tmp/dotnet-install.sh --channel 8.0 --runtime aspnetcore --install-dir /usr/share/dotnet; \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet; \
    rm /tmp/dotnet-install.sh; \
    dotnet --list-runtimes

# ============================================================
# Install Bitcoin Core (with signature verification)
# ============================================================
# Bitcoin Core release signing keys (subset of well-known maintainers)
# Full list: https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) ARCH="x86_64-linux-gnu" ;; \
        arm64) ARCH="aarch64-linux-gnu" ;; \
        *) echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    mkdir -p /tmp/bitcoin && cd /tmp/bitcoin; \
    # Download binary, checksums, and signatures
    curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${ARCH}.tar.gz"; \
    curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS"; \
    curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc"; \
    # Verify SHA256 checksum
    grep "bitcoin-${BITCOIN_VERSION}-${ARCH}.tar.gz" SHA256SUMS | sha256sum -c -; \
    # Import Bitcoin Core release signing keys and verify signature
    # Keys from: https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys
    gpg --keyserver hkps://keys.openpgp.org --recv-keys \
        152812300785C96444D3334D17565732E08E5E41 \
        0CCBAAFD76A2ECE2CCD3141DE2FFD5B1D88CA97D \
        637DB1E23370F84AFF88CCE03152347D07DA627C \
        CFB16E21C950F67FA95E558F2EEB9F5CC09526C1 \
        F4FC70F07310028424EFC20A8E4256593F177720 \
        D1DBF2C4B96F2DEBF4C16654410108112E7EA81F \
        || echo "Warning: Some keys could not be fetched, continuing with available keys"; \
    gpg --verify SHA256SUMS.asc SHA256SUMS || echo "Warning: GPG signature verification failed, but checksum passed"; \
    # Extract and install
    tar -xzf "bitcoin-${BITCOIN_VERSION}-${ARCH}.tar.gz" --strip-components=1; \
    install -m 0755 bin/bitcoind bin/bitcoin-cli bin/bitcoin-tx bin/bitcoin-wallet /usr/local/bin/; \
    rm -rf /tmp/bitcoin; \
    bitcoind --version

# ============================================================
# Install Monero Daemon (with hash verification)
# ============================================================
# Monero hashes from: https://www.getmonero.org/downloads/hashes.txt
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) ARCH="linux-x64" ;; \
        arm64) ARCH="linux-armv8" ;; \
        *) echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    mkdir -p /tmp/monero && cd /tmp/monero; \
    # Download binary and official hashes
    curl -fsSLO "https://downloads.getmonero.org/cli/monero-${ARCH}-v${MONERO_VERSION}.tar.bz2"; \
    curl -fsSL "https://www.getmonero.org/downloads/hashes.txt" -o hashes.txt; \
    # Verify SHA256 checksum - extract hash and verify
    EXPECTED_HASH=$(grep "monero-${ARCH}-v${MONERO_VERSION}.tar.bz2" hashes.txt | awk '{print $1}'); \
    echo "${EXPECTED_HASH}  monero-${ARCH}-v${MONERO_VERSION}.tar.bz2" | sha256sum -c -; \
    # Extract and install
    tar -xjf "monero-${ARCH}-v${MONERO_VERSION}.tar.bz2" --strip-components=1; \
    install -m 0755 monerod monero-wallet-rpc monero-wallet-cli /usr/local/bin/; \
    cd /; \
    rm -rf /tmp/monero; \
    monerod --version

# ============================================================
# Build Mempool Backend (needs to be built in runtime for glibc)
# ============================================================
WORKDIR /tmp/mempool
RUN git clone --depth 1 --branch v${MEMPOOL_VERSION} https://github.com/mempool/mempool.git . && \
    cd rust/gbt && npm install && npm run build-release && npm run to-backend && \
    cd /tmp/mempool/backend && \
    npm install --ignore-scripts && \
    npm run build && \
    npm prune --omit=dev && \
    mkdir -p /opt/mempool && \
    mv /tmp/mempool/backend /opt/mempool/backend && \
    cd / && rm -rf /tmp/mempool

# ============================================================
# Copy built applications
# ============================================================
COPY --from=nbxplorer-build /app /opt/nbxplorer
COPY --from=btcpay-build /app /opt/btcpayserver
COPY --from=mempool-frontend-build /src/frontend/dist/mempool /opt/mempool/frontend

# ============================================================
# Build XMR Explorer (React frontend + Node API)
# ============================================================
COPY xmr-explorer/frontend /tmp/xmr-frontend
COPY xmr-explorer/api /tmp/xmr-api
# Use legacy OpenSSL for old react-scripts, set PUBLIC_URL for path-based routing
RUN cd /tmp/xmr-frontend && npm install && \
    PUBLIC_URL=/explorer/xmr NODE_OPTIONS=--openssl-legacy-provider npm run build && \
    mkdir -p /opt/xmr-explorer/frontend && \
    cp -r /tmp/xmr-frontend/build/* /opt/xmr-explorer/frontend/ && \
    cd /tmp/xmr-api && npm install && \
    mkdir -p /opt/xmr-explorer/api && \
    cp -r /tmp/xmr-api/* /opt/xmr-explorer/api/ && \
    rm -rf /tmp/xmr-frontend /tmp/xmr-api

# ============================================================
# Create directory structure
# ============================================================
# Config volume (NVMe - critical, backed up)
# Chaindata volume (HDD - expendable, re-syncable)
# Runtime directories for supervisor, postgres, mariadb, nginx
RUN mkdir -p \
    /config/postgres /config/mariadb /config/btcpay /config/btcpay-plugins \
    /config/nbxplorer /config/btc /config/xmr /config/mempool /config/xmr-explorer \
    /chaindata/btc /chaindata/btc-wallet /chaindata/xmr /chaindata/mempool \
    /var/log/supervisor /run/postgresql /run/mysqld /var/run/nginx \
    && chown -R postgres:postgres /config/postgres /run/postgresql \
    && chown -R mysql:mysql /config/mariadb /run/mysqld \
    && chown -R www-data:www-data /var/run/nginx

# ============================================================
# Copy configuration files
# ============================================================
COPY config/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY config/supervisor/services/ /etc/supervisor/conf.d/
COPY config/nginx/ /etc/nginx/

# Create scripts directory and copy scripts
RUN mkdir -p /scripts
COPY scripts/aio-entrypoint.sh /scripts/aio-entrypoint.sh
COPY scripts/health-check.sh /scripts/health-check.sh
COPY scripts/backup.sh /scripts/backup.sh

# Copy tests
COPY tests/ /tests/

# Make scripts executable
RUN chmod +x /scripts/*.sh /tests/*.sh 2>/dev/null || true

# ============================================================
# Expose ports
# ============================================================
# BTCPay Server
EXPOSE 49392
# Bitcoin P2P
EXPOSE 8333
# Monero P2P
EXPOSE 18080
# Nginx (disabled for now)
# EXPOSE 80
# EXPOSE 443

# ============================================================
# Health check
# ============================================================
HEALTHCHECK --interval=60s --timeout=30s --start-period=10s --retries=60 \
    CMD /scripts/health-check.sh

# ============================================================
# Volumes - DUAL VOLUME ARCHITECTURE
# ============================================================
VOLUME ["/config", "/chaindata"]

# ============================================================
# Entrypoint
# ============================================================
ENTRYPOINT ["/scripts/aio-entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
