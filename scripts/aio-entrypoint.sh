#!/bin/bash
# ============================================================
# BTCPay Server AIO - Entrypoint Script
# ============================================================
# Initializes all services and configuration on first run
# ============================================================

set -e

# ============================================================
# Color Output
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# Banner
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}       BTCPay Server - All-in-One Container               ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}       Self-hosted Bitcoin Payment Processor              ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# Environment Defaults
# ============================================================
export BTCPAY_NETWORK="${BTCPAY_NETWORK:-mainnet}"
export BTCPAY_HOST="${BTCPAY_HOST:-localhost}"
export BTCPAY_PROTOCOL="${BTCPAY_PROTOCOL:-http}"
export BTCPAY_ROOTPATH="${BTCPAY_ROOTPATH:-/}"
export BITCOIN_PRUNE="${BITCOIN_PRUNE:-550}"
export BITCOIN_DBCACHE="${BITCOIN_DBCACHE:-512}"
export BITCOIN_MAXMEMPOOL="${BITCOIN_MAXMEMPOOL:-300}"
export POSTGRES_USER="${POSTGRES_USER:-btcpay}"
export POSTGRES_DB="${POSTGRES_DB:-btcpay}"

# Generate random password if not set
if [ -z "$POSTGRES_PASSWORD" ]; then
    export POSTGRES_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
    log_warn "Generated random PostgreSQL password"
fi

# Bitcoin RPC credentials
export BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-btcpayrpc}"
if [ -z "$BITCOIN_RPC_PASSWORD" ]; then
    export BITCOIN_RPC_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
    log_warn "Generated random Bitcoin RPC password"
fi

log_info "Network: ${BTCPAY_NETWORK}"
log_info "Host: ${BTCPAY_HOST}"
log_info "Protocol: ${BTCPAY_PROTOCOL}"

# ============================================================
# Initialize PostgreSQL
# ============================================================
init_postgres() {
    log_info "Initializing PostgreSQL..."

    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        log_info "Creating new PostgreSQL database cluster..."
        chown -R postgres:postgres /data/postgres /run/postgresql
        su-exec postgres initdb -D "$PGDATA" --auth-local=trust --auth-host=md5

        # Configure PostgreSQL
        cat >> "$PGDATA/postgresql.conf" <<EOF
listen_addresses = 'localhost'
port = 5432
max_connections = 100
shared_buffers = 256MB
random_page_cost = 1.0
EOF

        # Configure authentication
        cat > "$PGDATA/pg_hba.conf" <<EOF
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

        log_success "PostgreSQL cluster created"
    else
        log_info "PostgreSQL data directory exists"
        chown -R postgres:postgres /data/postgres /run/postgresql
    fi

    # Start PostgreSQL temporarily to create database/user
    su-exec postgres pg_ctl -D "$PGDATA" -w start

    # Create user and databases if they don't exist
    su-exec postgres psql -v ON_ERROR_STOP=0 <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
        CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${POSTGRES_DB}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${POSTGRES_DB}')\gexec
SELECT 'CREATE DATABASE nbxplorer' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nbxplorer')\gexec

GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON DATABASE nbxplorer TO ${POSTGRES_USER};
EOF

    su-exec postgres pg_ctl -D "$PGDATA" -w stop
    log_success "PostgreSQL initialized"
}

# ============================================================
# Initialize Bitcoin Core
# ============================================================
init_bitcoin() {
    log_info "Initializing Bitcoin Core..."

    mkdir -p /data/bitcoin /data/bitcoin-wallet

    # Determine network-specific settings
    case "$BTCPAY_NETWORK" in
        mainnet)
            BITCOIN_NETWORK_SECTION=""
            BITCOIN_PORT=8333
            BITCOIN_RPC_PORT=8332
            ;;
        testnet)
            BITCOIN_NETWORK_SECTION="testnet=1"
            BITCOIN_PORT=18333
            BITCOIN_RPC_PORT=18332
            ;;
        regtest)
            BITCOIN_NETWORK_SECTION="regtest=1"
            BITCOIN_PORT=18444
            BITCOIN_RPC_PORT=18443
            ;;
        signet)
            BITCOIN_NETWORK_SECTION="signet=1"
            BITCOIN_PORT=38333
            BITCOIN_RPC_PORT=38332
            ;;
        *)
            log_error "Unknown network: $BTCPAY_NETWORK"
            exit 1
            ;;
    esac

    # Create bitcoin.conf
    cat > /data/bitcoin/bitcoin.conf <<EOF
# Network
${BITCOIN_NETWORK_SECTION}

# RPC Settings
server=1
rpcuser=${BITCOIN_RPC_USER}
rpcpassword=${BITCOIN_RPC_PASSWORD}
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=43782

# Network Settings
port=39388
bind=0.0.0.0

# Performance
dbcache=${BITCOIN_DBCACHE}
maxmempool=${BITCOIN_MAXMEMPOOL}
prune=${BITCOIN_PRUNE}

# ZMQ for NBXplorer
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
zmqpubhashblock=tcp://127.0.0.1:28334

# Wallet
disablewallet=0
walletdir=/data/bitcoin-wallet

# Misc
txindex=0
EOF

    log_success "Bitcoin Core configured"
}

# ============================================================
# Initialize NBXplorer
# ============================================================
init_nbxplorer() {
    log_info "Initializing NBXplorer..."

    mkdir -p /data/nbxplorer

    # Create NBXplorer settings
    cat > /data/nbxplorer/settings.config <<EOF
network=${BTCPAY_NETWORK}
btcrpcurl=http://127.0.0.1:43782/
btcrpcuser=${BITCOIN_RPC_USER}
btcrpcpassword=${BITCOIN_RPC_PASSWORD}
btcnodeendpoint=127.0.0.1:39388
postgres=Host=127.0.0.1;Port=5432;Database=nbxplorer;Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}
automigrate=1
noauth=1
exposerpc=1
bind=127.0.0.1
port=32838
EOF

    log_success "NBXplorer configured"
}

# ============================================================
# Initialize BTCPay Server
# ============================================================
init_btcpay() {
    log_info "Initializing BTCPay Server..."

    mkdir -p /data/btcpay /data/btcpay-plugins

    # Build external URL
    if [ "$BTCPAY_PROTOCOL" = "https" ]; then
        BTCPAY_EXTERNAL_URL="https://${BTCPAY_HOST}${BTCPAY_ROOTPATH}"
    else
        BTCPAY_EXTERNAL_URL="http://${BTCPAY_HOST}${BTCPAY_ROOTPATH}"
    fi

    # Create BTCPay settings
    cat > /data/btcpay/settings.config <<EOF
network=${BTCPAY_NETWORK}
bind=0.0.0.0
port=49392
postgres=Host=127.0.0.1;Port=5432;Database=${POSTGRES_DB};Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}
btcexplorerurl=http://127.0.0.1:32838/
btcexplorercookiefile=
rootpath=${BTCPAY_ROOTPATH}
externalurl=${BTCPAY_EXTERNAL_URL}
plugindir=/data/btcpay-plugins
EOF

    log_success "BTCPay Server configured"
}

# ============================================================
# Wait for Service
# ============================================================
wait_for_service() {
    local name=$1
    local host=$2
    local port=$3
    local max_attempts=${4:-60}
    local attempt=1

    log_info "Waiting for ${name} on ${host}:${port}..."

    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_success "${name} is ready"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    log_error "${name} failed to start"
    return 1
}

# ============================================================
# Main
# ============================================================
main() {
    # Initialize all services
    init_postgres
    init_bitcoin
    init_nbxplorer
    init_btcpay

    log_info "Starting services via supervisor..."
    echo ""

    # Execute the command (supervisor)
    exec "$@"
}

main "$@"
