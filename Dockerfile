# ============================================================
# BTCPay Server - All-in-One Immutable Image
# ============================================================
# A self-contained image with all services for simple deployment.
# Optimized for Coolify and single-server deployments.
#
# Services included:
#   - BTCPay Server (payment processor)
#   - NBXplorer (blockchain indexer)
#   - Bitcoin Core (full/pruned node)
#   - PostgreSQL (database)
#
# Build:  docker build -t btcpay-aio .
# Run:    docker run -d -p 80:49392 -v btcpay-data:/data btcpay-aio
# ============================================================

# Build arguments for version pinning
ARG ALPINE_VERSION=3.22
ARG BITCOIN_VERSION=28.0
ARG NBXPLORER_VERSION=2.5.16
ARG BTCPAY_VERSION=2.0.6
ARG POSTGRES_VERSION=16

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
# Stage 3: Runtime Image
# ============================================================
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Snider <snider@host.uk.com>"
LABEL org.opencontainers.image.source="https://github.com/host-uk/docker-server-blockchain"
LABEL org.opencontainers.image.description="BTCPay Server All-in-One - Self-hosted Bitcoin payment processor"
LABEL org.opencontainers.image.licenses="EUPL-1.2"
LABEL org.opencontainers.image.vendor="Host UK"
LABEL org.opencontainers.image.title="BTCPay Server AIO"

# Version args for runtime
ARG BITCOIN_VERSION
ARG POSTGRES_VERSION

# Environment defaults
ENV BTCPAY_NETWORK=mainnet \
    BTCPAY_HOST=localhost \
    BTCPAY_PROTOCOL=http \
    BTCPAY_ROOTPATH=/ \
    BITCOIN_PRUNE=550 \
    BITCOIN_DBCACHE=512 \
    BITCOIN_MAXMEMPOOL=300 \
    POSTGRES_USER=btcpay \
    POSTGRES_DB=btcpay \
    PGDATA=/data/postgres \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# ============================================================
# Install runtime dependencies
# ============================================================
RUN apk add --no-cache \
    # Process manager
    supervisor \
    # .NET runtime
    aspnetcore8-runtime \
    icu-libs \
    # PostgreSQL
    postgresql${POSTGRES_VERSION} \
    postgresql${POSTGRES_VERSION}-contrib \
    # Bitcoin Core dependencies
    boost-system \
    boost-filesystem \
    boost-thread \
    libevent \
    libzmq \
    # Utilities
    curl \
    bash \
    su-exec \
    # Certificates
    ca-certificates

# ============================================================
# Install Bitcoin Core
# ============================================================
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) ARCH="x86_64-linux-gnu" ;; \
        arm64) ARCH="aarch64-linux-gnu" ;; \
        *) echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${ARCH}.tar.gz" \
        | tar -xz --strip-components=1 -C /usr/local; \
    # Verify installation
    bitcoind --version

# ============================================================
# Copy built applications
# ============================================================
COPY --from=nbxplorer-build /app /opt/nbxplorer
COPY --from=btcpay-build /app /opt/btcpayserver

# ============================================================
# Create directory structure
# ============================================================
RUN mkdir -p \
    /data/bitcoin \
    /data/bitcoin-wallet \
    /data/postgres \
    /data/nbxplorer \
    /data/btcpay \
    /data/btcpay-plugins \
    /var/log/supervisor \
    /run/postgresql \
    && chown -R postgres:postgres /data/postgres /run/postgresql

# ============================================================
# Copy configuration files
# ============================================================
COPY config/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY config/supervisor/services/ /etc/supervisor/conf.d/
COPY scripts/aio-entrypoint.sh /usr/local/bin/entrypoint.sh
COPY tests/ /tests/

RUN chmod +x /usr/local/bin/entrypoint.sh /tests/*.sh

# ============================================================
# Expose ports
# ============================================================
# BTCPay Server UI
EXPOSE 49392
# NBXplorer API (internal)
EXPOSE 32838
# Bitcoin RPC (internal)
EXPOSE 43782
# Bitcoin P2P
EXPOSE 39388
# PostgreSQL (internal)
EXPOSE 5432

# ============================================================
# Health check
# ============================================================
HEALTHCHECK --interval=60s --timeout=30s --start-period=300s --retries=3 \
    CMD curl -f http://localhost:49392/health || exit 1

# ============================================================
# Volume for all persistent data
# ============================================================
VOLUME ["/data"]

# ============================================================
# Entrypoint
# ============================================================
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
