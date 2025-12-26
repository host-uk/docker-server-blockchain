#!/bin/sh
# ============================================================
# Service Tests - Verify Running Services
# ============================================================
# Tests that require services to be running
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

section "Service Tests"

# ============================================================
# Port Availability
# ============================================================

subsection "Service Ports"

test_port "PostgreSQL (5432)" 5432 127.0.0.1
test_port "Bitcoin RPC (43782)" 43782 127.0.0.1
test_port "Bitcoin P2P (39388)" 39388 0.0.0.0
test_port "NBXplorer (32838)" 32838 127.0.0.1
test_port "BTCPay Server (49392)" 49392 0.0.0.0

# ============================================================
# PostgreSQL Health
# ============================================================

subsection "PostgreSQL"

test_command "PostgreSQL accepting connections" "pg_isready -U btcpay"
test_command "btcpay database exists" "psql -U btcpay -d btcpay -c 'SELECT 1'"
test_command "nbxplorer database exists" "psql -U btcpay -d nbxplorer -c 'SELECT 1'"

# ============================================================
# Bitcoin Core Health
# ============================================================

subsection "Bitcoin Core"

test_command "bitcoin-cli getblockchaininfo" "bitcoin-cli -rpcuser=\$BITCOIN_RPC_USER -rpcpassword=\$BITCOIN_RPC_PASSWORD getblockchaininfo"
test_command "bitcoin-cli getnetworkinfo" "bitcoin-cli -rpcuser=\$BITCOIN_RPC_USER -rpcpassword=\$BITCOIN_RPC_PASSWORD getnetworkinfo"

# ============================================================
# NBXplorer Health
# ============================================================

subsection "NBXplorer"

test_http "NBXplorer health endpoint" "http://127.0.0.1:32838/health" 200

# ============================================================
# BTCPay Server Health
# ============================================================

subsection "BTCPay Server"

test_http "BTCPay health endpoint" "http://127.0.0.1:49392/health" 200
test_http "BTCPay main page" "http://127.0.0.1:49392/" 200

# ============================================================
# Supervisor Status
# ============================================================

subsection "Supervisor"

test_command "supervisorctl status" "supervisorctl status"
test_contains "postgres running" "RUNNING" "supervisorctl status postgres"
test_contains "bitcoind running" "RUNNING" "supervisorctl status bitcoind"
test_contains "nbxplorer running" "RUNNING" "supervisorctl status nbxplorer"
test_contains "btcpayserver running" "RUNNING" "supervisorctl status btcpayserver"

# ============================================================
# Summary
# ============================================================

summary
