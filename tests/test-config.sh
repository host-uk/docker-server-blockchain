#!/bin/sh
# ============================================================
# Configuration Tests - Verify Service Configuration
# ============================================================
# Tests that verify configuration files are created correctly
# These tests require the entrypoint to have run (config initialized)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

section "Configuration Tests"

# ============================================================
# Dual-Volume Structure (/config - NVMe RAID)
# ============================================================

subsection "Config Volume Structure (/config)"

test_dir "postgres config dir" "${CONFIG_DIR:-/config}/postgres"
test_dir "btcpay config dir" "${CONFIG_DIR:-/config}/btcpay"
test_dir "btcpay-plugins dir" "${CONFIG_DIR:-/config}/btcpay-plugins"
test_dir "nbxplorer config dir" "${CONFIG_DIR:-/config}/nbxplorer"
test_dir "btc config dir" "${CONFIG_DIR:-/config}/btc"
test_dir "xmr config dir" "${CONFIG_DIR:-/config}/xmr"
test_dir "mempool config dir" "${CONFIG_DIR:-/config}/mempool"
test_dir "backups dir" "${CONFIG_DIR:-/config}/backups"

# ============================================================
# Dual-Volume Structure (/chaindata - HDD)
# ============================================================

subsection "Chaindata Volume Structure (/chaindata)"

test_dir "bitcoin chaindata dir" "${CHAINDATA_DIR:-/chaindata}/btc"
test_dir "monero chaindata dir" "${CHAINDATA_DIR:-/chaindata}/xmr"
test_dir "mempool cache dir" "${CHAINDATA_DIR:-/chaindata}/mempool"

# ============================================================
# Credentials File
# ============================================================

subsection "Credentials"

test_file "credentials file exists" "${CONFIG_DIR:-/config}/.credentials"
test_contains "credentials has BITCOIN_RPC_PASSWORD" "BITCOIN_RPC_PASSWORD=" "cat ${CONFIG_DIR:-/config}/.credentials"
test_contains "credentials has MONERO_RPC_PASSWORD" "MONERO_RPC_PASSWORD=" "cat ${CONFIG_DIR:-/config}/.credentials"
test_contains "credentials has POSTGRES_PASSWORD" "POSTGRES_PASSWORD=" "cat ${CONFIG_DIR:-/config}/.credentials"

# ============================================================
# Bitcoin Core Configuration
# ============================================================

subsection "Bitcoin Core Configuration"

test_file "bitcoin.conf exists" "${CONFIG_DIR:-/config}/btc/bitcoin.conf"
test_contains "bitcoin.conf has server=1" "server=1" "cat ${CONFIG_DIR:-/config}/btc/bitcoin.conf"
test_contains "bitcoin.conf has rpcuser" "rpcuser=" "cat ${CONFIG_DIR:-/config}/btc/bitcoin.conf"
test_contains "bitcoin.conf has rpcpassword" "rpcpassword=" "cat ${CONFIG_DIR:-/config}/btc/bitcoin.conf"
test_contains "bitcoin.conf has zmqpubrawblock" "zmqpubrawblock=" "cat ${CONFIG_DIR:-/config}/btc/bitcoin.conf"
test_contains "bitcoin.conf has zmqpubrawtx" "zmqpubrawtx=" "cat ${CONFIG_DIR:-/config}/btc/bitcoin.conf"
test_contains "bitcoin.conf has zmqpubhashblock" "zmqpubhashblock=" "cat ${CONFIG_DIR:-/config}/btc/bitcoin.conf"

# ============================================================
# Monero Configuration
# ============================================================

subsection "Monero Configuration"

test_file "monero.conf exists" "${CONFIG_DIR:-/config}/xmr/monero.conf"
test_contains "monero.conf has data-dir" "data-dir=" "cat ${CONFIG_DIR:-/config}/xmr/monero.conf"
test_contains "monero.conf has rpc-login" "rpc-login=" "cat ${CONFIG_DIR:-/config}/xmr/monero.conf"
test_contains "monero.conf has confirm-external-bind" "confirm-external-bind" "cat ${CONFIG_DIR:-/config}/xmr/monero.conf"

# ============================================================
# NBXplorer Configuration
# ============================================================

subsection "NBXplorer Configuration"

test_file "nbxplorer settings.config exists" "${CONFIG_DIR:-/config}/nbxplorer/settings.config"
test_contains "nbxplorer has network setting" "network=" "cat ${CONFIG_DIR:-/config}/nbxplorer/settings.config"
test_contains "nbxplorer has postgres setting" "postgres=" "cat ${CONFIG_DIR:-/config}/nbxplorer/settings.config"
test_contains "nbxplorer has btcrpcurl" "btcrpcurl=" "cat ${CONFIG_DIR:-/config}/nbxplorer/settings.config"

# ============================================================
# BTCPay Server Configuration
# ============================================================

subsection "BTCPay Server Configuration"

test_file "btcpay settings.config exists" "${CONFIG_DIR:-/config}/btcpay/settings.config"
test_contains "btcpay has network setting" "network=" "cat ${CONFIG_DIR:-/config}/btcpay/settings.config"
test_contains "btcpay has postgres setting" "postgres=" "cat ${CONFIG_DIR:-/config}/btcpay/settings.config"
test_contains "btcpay has explorerurl" "btcexplorerurl=" "cat ${CONFIG_DIR:-/config}/btcpay/settings.config"
test_contains "btcpay has bind setting" "bind=" "cat ${CONFIG_DIR:-/config}/btcpay/settings.config"

# ============================================================
# Mempool Configuration
# ============================================================

subsection "Mempool Configuration"

test_file "mempool config exists" "${CONFIG_DIR:-/config}/mempool/mempool-config.json"
test_contains "mempool has MEMPOOL section" "MEMPOOL" "cat ${CONFIG_DIR:-/config}/mempool/mempool-config.json"
test_contains "mempool has CORE_RPC section" "CORE_RPC" "cat ${CONFIG_DIR:-/config}/mempool/mempool-config.json"
test_contains "mempool has DATABASE section" "DATABASE" "cat ${CONFIG_DIR:-/config}/mempool/mempool-config.json"

# ============================================================
# PostgreSQL Configuration
# ============================================================

subsection "PostgreSQL Configuration"

test_file "postgresql.conf exists" "${CONFIG_DIR:-/config}/postgres/postgresql.conf"
test_file "pg_hba.conf exists" "${CONFIG_DIR:-/config}/postgres/pg_hba.conf"

# ============================================================
# Path Separation Verification
# ============================================================

subsection "Path Separation (Config vs Chaindata)"

# Verify critical data is on /config (NVMe)
test_file "postgres data on config" "${CONFIG_DIR:-/config}/postgres/PG_VERSION"

# Verify chain data is on /chaindata (HDD)
# Note: These may not exist until sync starts
test_dir "bitcoin blocks dir" "${CHAINDATA_DIR:-/chaindata}/btc"
test_dir "monero lmdb dir" "${CHAINDATA_DIR:-/chaindata}/xmr"

# ============================================================
# Summary
# ============================================================

summary
