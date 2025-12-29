#!/bin/bash
# ============================================================
# BTCPay Server AIO - Entrypoint Script
# ============================================================
# Initializes all services with dual-volume architecture:
#   /config    = NVMe RAID 1 (critical, backed up)
#   /chaindata = HDD (expendable, re-syncable)
# ============================================================

set -e

# ============================================================
# Color Output
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ============================================================
# Banner
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}         BTCPay Server - All-in-One Container                 ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}         Multi-Crypto Payment Processor                       ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                              ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Services: BTCPay | Bitcoin | Monero | Mempool | PostgreSQL  ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# Storage Architecture Paths
# ============================================================
# CRITICAL DATA (NVMe RAID 1 - /config) - BACKED UP
export CONFIG_DIR="${CONFIG_DIR:-/config}"
export PGDATA="${CONFIG_DIR}/postgres"
export BTCPAY_DATADIR="${CONFIG_DIR}/btcpay"
export BTCPAY_PLUGINDIR="${CONFIG_DIR}/btcpay-plugins"
export NBXPLORER_DATADIR="${CONFIG_DIR}/nbxplorer"
export BTC_CONFDIR="${CONFIG_DIR}/btc"
export XMR_CONFDIR="${CONFIG_DIR}/xmr"
export MEMPOOL_CONFDIR="${CONFIG_DIR}/mempool"

# EXPENDABLE DATA (HDD 10TB - /chaindata) - NOT BACKED UP
export CHAINDATA_DIR="${CHAINDATA_DIR:-/chaindata}"
export BTC_DATADIR="${CHAINDATA_DIR}/btc"
export BTC_WALLETDIR="${CHAINDATA_DIR}/btc-wallet"
export XMR_DATADIR="${CHAINDATA_DIR}/xmr"
export MEMPOOL_DATADIR="${CHAINDATA_DIR}/mempool"

# ============================================================
# Environment Defaults
# ============================================================
export BTCPAY_NETWORK="${BTCPAY_NETWORK:-mainnet}"
export BTCPAY_HOST="${BTCPAY_HOST:-localhost}"
export BTCPAY_PROTOCOL="${BTCPAY_PROTOCOL:-https}"
export BTCPAY_ROOTPATH="${BTCPAY_ROOTPATH:-/}"
export DOMAIN="${DOMAIN:-pay.host.uk.com}"

# Bitcoin settings
export BITCOIN_PRUNE="${BITCOIN_PRUNE:-0}"
export BITCOIN_DBCACHE="${BITCOIN_DBCACHE:-4096}"
export BITCOIN_MAXMEMPOOL="${BITCOIN_MAXMEMPOOL:-1000}"
export BITCOIN_TXINDEX="${BITCOIN_TXINDEX:-1}"

# Monero settings
export MONERO_PRUNE="${MONERO_PRUNE:-0}"
export XMR_WALLET_DIR="${CONFIG_DIR}/xmr-wallets"

# Litecoin settings
export LTC_CONFDIR="${CONFIG_DIR}/ltc"
export LTC_DATADIR="${CHAINDATA_DIR}/ltc"
export LITECOIN_RPC_USER="${LITECOIN_RPC_USER:-ltcrpc}"
export LITECOIN_P2P_PORT="${LITECOIN_P2P_PORT:-9333}"
export LITECOIN_RPC_PORT="${LITECOIN_RPC_PORT:-9332}"

# PostgreSQL
export POSTGRES_USER="${POSTGRES_USER:-btcpay}"
export POSTGRES_DB="${POSTGRES_DB:-btcpay}"

# ============================================================
# Password Management
# ============================================================
# Passwords are stored persistently in /config/.secrets to survive restarts.
# Priority: ENV variable > stored secret > generate new
# ============================================================

SECRETS_DIR="${CONFIG_DIR:-.}/.secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

load_or_generate_password() {
    local var_name=$1
    local secret_file="${SECRETS_DIR}/${var_name}"
    local current_value="${!var_name}"

    if [ -n "$current_value" ]; then
        # ENV variable is set, use it and save for future
        echo "$current_value" > "$secret_file"
        chmod 600 "$secret_file"
    elif [ -f "$secret_file" ]; then
        # Load from stored secret
        export "$var_name"="$(cat "$secret_file")"
        log_info "Loaded ${var_name} from stored secrets"
    else
        # Generate new password and store it
        local new_pass=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
        export "$var_name"="$new_pass"
        echo "$new_pass" > "$secret_file"
        chmod 600 "$secret_file"
        log_warn "Generated and stored new ${var_name}"
    fi
}

load_or_generate_password "POSTGRES_PASSWORD"

export BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-btcpayrpc}"
load_or_generate_password "BITCOIN_RPC_PASSWORD"

export MONERO_RPC_USER="${MONERO_RPC_USER:-monerorpc}"
load_or_generate_password "MONERO_RPC_PASSWORD"

load_or_generate_password "LITECOIN_RPC_PASSWORD"

# Monero Plugin settings (for BTCPay Server) - must be after password loading
export BTCPAY_XMR_DAEMON_URI="${BTCPAY_XMR_DAEMON_URI:-http://127.0.0.1:18081}"
export BTCPAY_XMR_DAEMON_USERNAME="${MONERO_RPC_USER}"
export BTCPAY_XMR_DAEMON_PASSWORD="${MONERO_RPC_PASSWORD}"
export BTCPAY_XMR_WALLET_DAEMON_URI="${BTCPAY_XMR_WALLET_DAEMON_URI:-http://127.0.0.1:18082}"
export BTCPAY_XMR_WALLET_DAEMON_WALLETDIR="${XMR_WALLET_DIR}"

# Litecoin MWEB Plugin settings
export BTCPAY_LTC_MWEB_DAEMON_URI="${BTCPAY_LTC_MWEB_DAEMON_URI:-http://127.0.0.1:12345}"

# ============================================================
# Display Configuration
# ============================================================
log_section "Configuration"
log_info "Network:     ${BTCPAY_NETWORK}"
log_info "Host:        ${BTCPAY_HOST}"
log_info "Protocol:    ${BTCPAY_PROTOCOL}"
log_info "Domain:      ${DOMAIN}"
echo ""
log_info "Config Volume:    ${CONFIG_DIR} (NVMe - critical, backed up)"
log_info "Chaindata Volume: ${CHAINDATA_DIR} (HDD - expendable)"

# ============================================================
# Verify Volume Mounts
# ============================================================
log_section "Volume Verification"

verify_mount() {
    local path=$1
    local name=$2
    local critical=$3

    if mountpoint -q "$path" 2>/dev/null || [ -d "$path" ]; then
        local size=$(df -h "$path" 2>/dev/null | tail -1 | awk '{print $2}')
        local used=$(df -h "$path" 2>/dev/null | tail -1 | awk '{print $5}')
        log_success "$name: $size (${used} used)"
        return 0
    else
        if [ "$critical" = "true" ]; then
            log_error "$name not mounted at $path - CRITICAL!"
            return 1
        else
            log_warn "$name not mounted at $path - using container storage"
            return 0
        fi
    fi
}

verify_mount "$CONFIG_DIR" "Config (NVMe)" "true"
verify_mount "$CHAINDATA_DIR" "Chaindata (HDD)" "false"

# ============================================================
# Create Directory Structure
# ============================================================
log_section "Directory Structure"

# Config directories (critical)
mkdir -p "$PGDATA" "$BTCPAY_DATADIR" "$BTCPAY_PLUGINDIR" "$NBXPLORER_DATADIR"
mkdir -p "$BTC_CONFDIR" "$XMR_CONFDIR" "$LTC_CONFDIR" "$MEMPOOL_CONFDIR" "$XMR_WALLET_DIR"
mkdir -p /run/postgresql

# Chaindata directories (expendable)
mkdir -p "$BTC_DATADIR" "$BTC_WALLETDIR" "$XMR_DATADIR" "$LTC_DATADIR" "$MEMPOOL_DATADIR"

# Set permissions
chown -R postgres:postgres "$PGDATA" /run/postgresql

log_success "Directory structure ready"

# ============================================================
# Initialize PostgreSQL
# ============================================================
init_postgres() {
    log_section "PostgreSQL"

    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        log_info "Creating new PostgreSQL database cluster..."
        gosu postgres initdb -D "$PGDATA" --auth-local=trust --auth-host=scram-sha-256

        # Configure PostgreSQL for production
        cat >> "$PGDATA/postgresql.conf" <<EOF
# Connection
listen_addresses = 'localhost'
port = 5432
max_connections = 200

# Performance (tuned for 1TB NVMe)
shared_buffers = 512MB
effective_cache_size = 2GB
maintenance_work_mem = 256MB
work_mem = 16MB
random_page_cost = 1.1
effective_io_concurrency = 200

# WAL
wal_buffers = 16MB
checkpoint_completion_target = 0.9
max_wal_size = 2GB
min_wal_size = 512MB

# Logging
log_destination = 'stderr'
logging_collector = off
EOF

        # Configure authentication
        cat > "$PGDATA/pg_hba.conf" <<EOF
local   all             all                                     trust
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
EOF

        log_success "PostgreSQL cluster created"
    else
        log_info "PostgreSQL data directory exists"
    fi

    # Clean up stale PID file if exists (from unclean shutdown)
    if [ -f "$PGDATA/postmaster.pid" ]; then
        log_info "Removing stale PostgreSQL PID file..."
        rm -f "$PGDATA/postmaster.pid"
    fi

    # Ensure socket directory exists
    mkdir -p /run/postgresql
    chown postgres:postgres /run/postgresql

    # Start PostgreSQL temporarily to create databases
    gosu postgres pg_ctl -D "$PGDATA" -w start -o "-c listen_addresses=localhost"

    # Create user and databases (always update password to ensure consistency)
    gosu postgres psql -v ON_ERROR_STOP=0 <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
        CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}' CREATEDB;
    ELSE
        -- User exists, update password to match current config
        ALTER USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${POSTGRES_DB}')\gexec
SELECT 'CREATE DATABASE nbxplorer OWNER ${POSTGRES_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nbxplorer')\gexec
SELECT 'CREATE DATABASE mempool OWNER ${POSTGRES_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mempool')\gexec

GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON DATABASE nbxplorer TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON DATABASE mempool TO ${POSTGRES_USER};
EOF

    # Grant schema permissions
    for db in "${POSTGRES_DB}" "nbxplorer" "mempool"; do
        gosu postgres psql -d "$db" -v ON_ERROR_STOP=0 <<EOF
GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${POSTGRES_USER};
EOF
    done

    gosu postgres pg_ctl -D "$PGDATA" -w stop
    log_success "PostgreSQL initialized"
}

# ============================================================
# Initialize MariaDB
# ============================================================
init_mariadb() {
    log_section "MariaDB"

    export MARIADB_DATADIR="/config/mariadb"
    export MYSQL_SOCKET="/run/mysqld/mysqld.sock"

    # Ensure socket directory exists with correct permissions
    mkdir -p /run/mysqld
    chown mysql:mysql /run/mysqld
    chmod 755 /run/mysqld

    if [ ! -d "$MARIADB_DATADIR/mysql" ]; then
        log_info "Initializing MariaDB data directory..."
        mysql_install_db --datadir="$MARIADB_DATADIR" --user=mysql
        log_success "MariaDB data directory created"
    else
        log_info "MariaDB data directory exists"
    fi

    # Start MariaDB temporarily to create databases
    mysqld_safe --datadir="$MARIADB_DATADIR" --socket="$MYSQL_SOCKET" &
    MYSQL_PID=$!

    # Wait for MariaDB socket to be ready
    log_info "Waiting for MariaDB to be ready..."
    for i in $(seq 1 60); do
        if [ -S "$MYSQL_SOCKET" ] && mysqladmin --socket="$MYSQL_SOCKET" ping &>/dev/null; then
            log_info "MariaDB is ready"
            break
        fi
        sleep 1
    done

    if [ ! -S "$MYSQL_SOCKET" ]; then
        log_warn "MariaDB socket not found, skipping database setup"
        return 0
    fi

    # Create mempool database and user
    mysql --socket="$MYSQL_SOCKET" -u root <<EOF
CREATE DATABASE IF NOT EXISTS mempool;
CREATE USER IF NOT EXISTS 'mempool'@'localhost' IDENTIFIED BY 'mempool';
GRANT ALL PRIVILEGES ON mempool.* TO 'mempool'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Stop MariaDB (supervisor will start it)
    mysqladmin --socket="$MYSQL_SOCKET" shutdown
    wait $MYSQL_PID 2>/dev/null || true

    log_success "MariaDB initialized"
}

# ============================================================
# Initialize Bitcoin Core
# ============================================================
init_bitcoin() {
    log_section "Bitcoin Core"

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

    # Export for other services
    export BITCOIN_RPC_PORT

    # Create bitcoin.conf in config volume
    cat > "${BTC_CONFDIR}/bitcoin.conf" <<EOF
# ============================================================
# Bitcoin Core Configuration
# Generated by BTCPay AIO Entrypoint
# ============================================================

# Network
${BITCOIN_NETWORK_SECTION}

# Data directories
# Config: ${BTC_CONFDIR} (NVMe - backed up)
# Data:   ${BTC_DATADIR} (HDD - expendable)
datadir=${BTC_DATADIR}
walletdir=${BTC_WALLETDIR}

# RPC Settings
server=1
rpcuser=${BITCOIN_RPC_USER}
rpcpassword=${BITCOIN_RPC_PASSWORD}
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=${BITCOIN_RPC_PORT}

# Network Settings
port=${BITCOIN_PORT}
bind=0.0.0.0
listen=1

# Performance (optimized for 10TB HDD + 4GB cache)
dbcache=${BITCOIN_DBCACHE}
maxmempool=${BITCOIN_MAXMEMPOOL}
prune=${BITCOIN_PRUNE}
txindex=${BITCOIN_TXINDEX}

# ZMQ for NBXplorer
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
zmqpubhashblock=tcp://127.0.0.1:28334

# Wallet
disablewallet=0

# Mempool settings
maxorphantx=100
mempoolexpiry=72
EOF

    log_info "Bitcoin data directory: ${BTC_DATADIR}"
    log_info "Bitcoin config: ${BTC_CONFDIR}/bitcoin.conf"
    log_success "Bitcoin Core configured"
}

# ============================================================
# Initialize Monero Daemon
# ============================================================
init_monero() {
    log_section "Monero Daemon"

    # Determine network-specific settings
    case "$BTCPAY_NETWORK" in
        mainnet)
            XMR_NETWORK=""
            XMR_RPC_PORT=18081
            XMR_P2P_PORT=18080
            ;;
        testnet)
            XMR_NETWORK="--testnet"
            XMR_RPC_PORT=28081
            XMR_P2P_PORT=28080
            ;;
        *)
            # Monero doesn't support regtest/signet, use stagenet
            XMR_NETWORK="--stagenet"
            XMR_RPC_PORT=38081
            XMR_P2P_PORT=38080
            log_warn "Monero using stagenet (no regtest/signet support)"
            ;;
    esac

    # Export for other services
    export XMR_RPC_PORT

    # Prune settings
    if [ "$MONERO_PRUNE" = "1" ] || [ "$MONERO_PRUNE" = "true" ]; then
        XMR_PRUNE_OPTS="--prune-blockchain --sync-pruned-blocks"
    else
        XMR_PRUNE_OPTS=""
    fi

    # Create monerod.conf in config volume
    cat > "${XMR_CONFDIR}/monerod.conf" <<EOF
# ============================================================
# Monero Daemon Configuration
# Generated by BTCPay AIO Entrypoint
# ============================================================

# Data directory (HDD - expendable)
data-dir=${XMR_DATADIR}

# RPC Settings
rpc-bind-ip=127.0.0.1
rpc-bind-port=${XMR_RPC_PORT}
confirm-external-bind=0
restricted-rpc=0
rpc-login=${MONERO_RPC_USER}:${MONERO_RPC_PASSWORD}

# P2P Settings
p2p-bind-port=${XMR_P2P_PORT}
p2p-bind-ip=0.0.0.0

# Database
db-sync-mode=safe:sync
block-sync-size=20

# Performance
max-concurrency=4

# Logging
log-level=0
log-file=/var/log/supervisor/monerod.log
EOF

    log_info "Monero data directory: ${XMR_DATADIR}"
    log_info "Monero config: ${XMR_CONFDIR}/monerod.conf"
    log_success "Monero Daemon configured"
}

# ============================================================
# Initialize Litecoin Core
# ============================================================
init_litecoin() {
    log_section "Litecoin Core"

    # Determine network-specific settings
    case "$BTCPAY_NETWORK" in
        mainnet)
            LITECOIN_NETWORK_SECTION=""
            LITECOIN_PORT=9333
            LITECOIN_RPC_PORT=9332
            ;;
        testnet)
            LITECOIN_NETWORK_SECTION="testnet=1"
            LITECOIN_PORT=19335
            LITECOIN_RPC_PORT=19332
            ;;
        regtest)
            LITECOIN_NETWORK_SECTION="regtest=1"
            LITECOIN_PORT=19444
            LITECOIN_RPC_PORT=19443
            ;;
        *)
            LITECOIN_NETWORK_SECTION=""
            LITECOIN_PORT=9333
            LITECOIN_RPC_PORT=9332
            ;;
    esac

    # Export for other services
    export LITECOIN_RPC_PORT
    export LITECOIN_P2P_PORT=$LITECOIN_PORT

    # Create litecoin.conf in config volume
    cat > "${LTC_CONFDIR}/litecoin.conf" <<EOF
# ============================================================
# Litecoin Core Configuration
# Generated by BTCPay AIO Entrypoint
# ============================================================

# Network
${LITECOIN_NETWORK_SECTION}

# Data directories
datadir=${LTC_DATADIR}

# RPC Settings
server=1
rpcuser=${LITECOIN_RPC_USER}
rpcpassword=${LITECOIN_RPC_PASSWORD}
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=${LITECOIN_RPC_PORT}

# Network Settings
port=${LITECOIN_PORT}
bind=0.0.0.0
listen=1

# Performance
txindex=1
prune=0

# ZMQ for NBXplorer
zmqpubrawblock=tcp://127.0.0.1:28335
zmqpubrawtx=tcp://127.0.0.1:28336

# MWEB
mweb=1
EOF

    log_info "Litecoin data directory: ${LTC_DATADIR}"
    log_info "Litecoin config: ${LTC_CONFDIR}/litecoin.conf"
    log_success "Litecoin Core configured"
}

# ============================================================
# Initialize NBXplorer
# ============================================================
init_nbxplorer() {
    log_section "NBXplorer"

    # Determine network directory name
    case "$BTCPAY_NETWORK" in
        mainnet) NBX_NETWORK_DIR="Main" ;;
        testnet) NBX_NETWORK_DIR="TestNet" ;;
        regtest) NBX_NETWORK_DIR="RegTest" ;;
        signet)  NBX_NETWORK_DIR="Signet" ;;
        *) NBX_NETWORK_DIR="Main" ;;
    esac

    mkdir -p "${NBXPLORER_DATADIR}/${NBX_NETWORK_DIR}"

    # Create NBXplorer settings
    cat > "${NBXPLORER_DATADIR}/${NBX_NETWORK_DIR}/settings.config" <<EOF
# NBXplorer Configuration
network=${BTCPAY_NETWORK}

# Chains to index (Bitcoin and Litecoin)
chains=btc,ltc

# Bitcoin connection
btcrpcurl=http://127.0.0.1:${BITCOIN_RPC_PORT}/
btcrpcuser=${BITCOIN_RPC_USER}
btcrpcpassword=${BITCOIN_RPC_PASSWORD}
btcnodeendpoint=127.0.0.1:${BITCOIN_PORT:-8333}

# Litecoin connection
ltcrpcurl=http://127.0.0.1:${LITECOIN_RPC_PORT}/
ltcrpcuser=${LITECOIN_RPC_USER}
ltcrpcpassword=${LITECOIN_RPC_PASSWORD}
ltcnodeendpoint=127.0.0.1:${LITECOIN_P2P_PORT:-9333}

# Database
postgres=Host=127.0.0.1;Port=5432;Database=nbxplorer;Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}

# Server settings
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
    log_section "BTCPay Server"

    # Determine network directory name (same as NBXplorer)
    case "$BTCPAY_NETWORK" in
        mainnet) BTCPAY_NETWORK_DIR="Main" ;;
        testnet) BTCPAY_NETWORK_DIR="TestNet" ;;
        regtest) BTCPAY_NETWORK_DIR="RegTest" ;;
        signet)  BTCPAY_NETWORK_DIR="Signet" ;;
        *) BTCPAY_NETWORK_DIR="Main" ;;
    esac

    mkdir -p "${BTCPAY_DATADIR}/${BTCPAY_NETWORK_DIR}"

    # Build external URL
    if [ "$BTCPAY_PROTOCOL" = "https" ]; then
        BTCPAY_EXTERNAL_URL="https://${BTCPAY_HOST}${BTCPAY_ROOTPATH}"
    else
        BTCPAY_EXTERNAL_URL="http://${BTCPAY_HOST}${BTCPAY_ROOTPATH}"
    fi

    # Create BTCPay settings
    cat > "${BTCPAY_DATADIR}/${BTCPAY_NETWORK_DIR}/settings.config" <<EOF
# BTCPay Server Configuration
network=${BTCPAY_NETWORK}

# Server settings
bind=0.0.0.0
port=49392
rootpath=${BTCPAY_ROOTPATH}
externalurl=${BTCPAY_EXTERNAL_URL}

# Database
postgres=Host=127.0.0.1;Port=5432;Database=${POSTGRES_DB};Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}

# NBXplorer (Bitcoin indexer)
btcexplorerurl=http://127.0.0.1:32838/
btcexplorercookiefile=

# Plugins
plugindir=${BTCPAY_PLUGINDIR}

# Monero Configuration
xmrrpcurl=http://127.0.0.1:${XMR_RPC_PORT:-18081}
xmrrpcuser=${MONERO_RPC_USER}
xmrrpcpassword=${MONERO_RPC_PASSWORD}
EOF

    log_info "BTCPay URL: ${BTCPAY_EXTERNAL_URL}"
    log_success "BTCPay Server configured"
}

# ============================================================
# Initialize Mempool Explorer
# ============================================================
init_mempool() {
    log_section "Mempool Block Explorer"

    # Create Mempool backend config
    # Using "none" backend with MariaDB for data persistence
    cat > "${MEMPOOL_CONFDIR}/mempool-config.json" <<EOF
{
  "MEMPOOL": {
    "NETWORK": "${BTCPAY_NETWORK}",
    "BACKEND": "none",
    "HTTP_PORT": 8999,
    "SPAWN_CLUSTER_PROCS": 0,
    "API_URL_PREFIX": "/api/v1/",
    "POLL_RATE_MS": 2000,
    "CACHE_DIR": "${MEMPOOL_DATADIR}/cache",
    "STDOUT_LOG_MIN_PRIORITY": "info"
  },
  "CORE_RPC": {
    "HOST": "127.0.0.1",
    "PORT": ${BITCOIN_RPC_PORT:-8332},
    "USERNAME": "${BITCOIN_RPC_USER}",
    "PASSWORD": "${BITCOIN_RPC_PASSWORD}"
  },
  "DATABASE": {
    "ENABLED": true,
    "HOST": "127.0.0.1",
    "PORT": 3306,
    "SOCKET": "/run/mysqld/mysqld.sock",
    "DATABASE": "mempool",
    "USERNAME": "mempool",
    "PASSWORD": "mempool"
  },
  "STATISTICS": {
    "ENABLED": true,
    "TX_PER_SECOND_SAMPLE_PERIOD": 150
  }
}
EOF

    mkdir -p "${MEMPOOL_DATADIR}/cache"

    log_info "Mempool explorer: http://localhost/explorer/btc"
    log_success "Mempool configured"
}

# ============================================================
# Initialize Monero Block Explorer
# ============================================================
init_xmr_explorer() {
    log_section "Monero Block Explorer"

    # Check if XMR explorer binary exists
    if [ ! -x "/opt/xmr-explorer/xmrblocks" ]; then
        log_warn "XMR explorer not available (ARM64 build may have failed)"
        return 0
    fi

    log_info "XMR explorer: http://localhost/explorer/xmr"
    log_success "XMR Explorer configured"
}

# ============================================================
# Save Credentials (for backup reference)
# ============================================================
save_credentials() {
    log_section "Credentials"

    local creds_file="${CONFIG_DIR}/.credentials"

    cat > "$creds_file" <<EOF
# ============================================================
# BTCPay AIO Credentials
# Generated: $(date -Iseconds)
# KEEP THIS FILE SECURE - STORE BACKUP SEPARATELY
# ============================================================

# PostgreSQL
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Bitcoin RPC
BITCOIN_RPC_USER=${BITCOIN_RPC_USER}
BITCOIN_RPC_PASSWORD=${BITCOIN_RPC_PASSWORD}

# Monero RPC
MONERO_RPC_USER=${MONERO_RPC_USER}
MONERO_RPC_PASSWORD=${MONERO_RPC_PASSWORD}

# BTCPay External URL
BTCPAY_URL=${BTCPAY_EXTERNAL_URL}
EOF

    chmod 600 "$creds_file"
    log_info "Credentials saved to ${creds_file}"
    log_warn "IMPORTANT: Back up this file securely!"
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

    log_error "${name} failed to start after ${max_attempts}s"
    return 1
}

# ============================================================
# Main
# ============================================================
main() {
    # Initialize all services
    init_postgres
    init_mariadb
    init_bitcoin
    init_litecoin
    init_monero
    init_nbxplorer
    init_btcpay
    init_mempool
    init_xmr_explorer
    save_credentials

    # Configure Nginx (SSL or HTTP-only based on certificate availability)
    log_section "Nginx Configuration"
    if [ -f "${CONFIG_DIR}/ssl/cert.pem" ] && [ -f "${CONFIG_DIR}/ssl/key.pem" ]; then
        log_success "SSL certificates found - enabling HTTPS"
        # Use the full SSL config (default nginx.conf)
        log_info "HTTPS enabled on port 443"
        log_info "HTTP on port 80 (with security headers)"
    else
        log_warn "No SSL certificates found at ${CONFIG_DIR}/ssl/"
        log_info "Using HTTP-only configuration"
        # Copy HTTP-only config
        cp /etc/nginx/nginx-http-only.conf /etc/nginx/nginx.conf
        log_info "To enable HTTPS, mount certificates to:"
        log_info "  - ${CONFIG_DIR}/ssl/cert.pem"
        log_info "  - ${CONFIG_DIR}/ssl/key.pem"
    fi

    log_section "Starting Services"
    echo ""
    log_info "Services will be managed by supervisor"
    log_info "Use 'supervisorctl status' to check status"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  URL Routing (via Nginx on port 80/443):"
    echo -e "  /"
    echo -e "    └─ BTCPay Server (payment processor)"
    echo -e "  /explorer/btc"
    echo -e "    └─ Mempool (Bitcoin block explorer)"
    echo -e "  /explorer/xmr"
    echo -e "    └─ Onion Monero Explorer"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Execute the command (supervisor)
    exec "$@"
}

main "$@"
