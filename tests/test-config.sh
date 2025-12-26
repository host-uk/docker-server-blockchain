#!/bin/sh
# ============================================================
# Configuration Tests - Verify Service Configuration
# ============================================================
# Tests that verify configuration files are created correctly
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

section "Configuration Tests"

# ============================================================
# Bitcoin Configuration
# ============================================================

subsection "Bitcoin Core Configuration"

test_file "bitcoin.conf exists" "/data/bitcoin/bitcoin.conf"
test_contains "bitcoin.conf has server=1" "server=1" "cat /data/bitcoin/bitcoin.conf"
test_contains "bitcoin.conf has rpcuser" "rpcuser=" "cat /data/bitcoin/bitcoin.conf"
test_contains "bitcoin.conf has zmqpubrawblock" "zmqpubrawblock=" "cat /data/bitcoin/bitcoin.conf"

# ============================================================
# NBXplorer Configuration
# ============================================================

subsection "NBXplorer Configuration"

test_file "nbxplorer settings.config exists" "/data/nbxplorer/settings.config"
test_contains "nbxplorer has network setting" "network=" "cat /data/nbxplorer/settings.config"
test_contains "nbxplorer has postgres setting" "postgres=" "cat /data/nbxplorer/settings.config"
test_contains "nbxplorer has btcrpcurl" "btcrpcurl=" "cat /data/nbxplorer/settings.config"

# ============================================================
# BTCPay Server Configuration
# ============================================================

subsection "BTCPay Server Configuration"

test_file "btcpay settings.config exists" "/data/btcpay/settings.config"
test_contains "btcpay has network setting" "network=" "cat /data/btcpay/settings.config"
test_contains "btcpay has postgres setting" "postgres=" "cat /data/btcpay/settings.config"
test_contains "btcpay has explorerurl" "btcexplorerurl=" "cat /data/btcpay/settings.config"
test_contains "btcpay has bind setting" "bind=" "cat /data/btcpay/settings.config"

# ============================================================
# PostgreSQL Configuration
# ============================================================

subsection "PostgreSQL Configuration"

test_file "postgresql.conf exists" "/data/postgres/postgresql.conf"
test_file "pg_hba.conf exists" "/data/postgres/pg_hba.conf"

# ============================================================
# Summary
# ============================================================

summary
