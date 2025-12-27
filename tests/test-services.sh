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
# Service Ports - Core Services
# ============================================================

subsection "Core Service Ports"

test_port "PostgreSQL (5432)" 5432 127.0.0.1
test_port "Bitcoin RPC (${BITCOIN_RPC_PORT:-8332})" "${BITCOIN_RPC_PORT:-8332}" 127.0.0.1
test_port "Bitcoin P2P (8333)" 8333 0.0.0.0
test_port "NBXplorer (32838)" 32838 127.0.0.1
test_port "BTCPay Server (49392)" 49392 0.0.0.0

# ============================================================
# Service Ports - Monero
# ============================================================

subsection "Monero Service Ports"

test_port "Monero RPC (${XMR_RPC_PORT:-18081})" "${XMR_RPC_PORT:-18081}" 127.0.0.1
test_port "Monero P2P (${XMR_P2P_PORT:-18080})" "${XMR_P2P_PORT:-18080}" 0.0.0.0

# ============================================================
# Service Ports - Mempool Explorer
# ============================================================

subsection "Mempool Explorer Ports"

test_port "Mempool Backend (8999)" 8999 127.0.0.1
test_port "Mempool Frontend/nginx (8080)" 8080 0.0.0.0

# ============================================================
# PostgreSQL Health
# ============================================================

subsection "PostgreSQL"

test_command "PostgreSQL accepting connections" "pg_isready -U ${POSTGRES_USER:-btcpay}"
test_command "btcpay database exists" "psql -U ${POSTGRES_USER:-btcpay} -d btcpay -c 'SELECT 1'"
test_command "nbxplorer database exists" "psql -U ${POSTGRES_USER:-btcpay} -d nbxplorer -c 'SELECT 1'"
test_command "mempool database exists" "psql -U ${POSTGRES_USER:-btcpay} -d mempool -c 'SELECT 1'"

# ============================================================
# Bitcoin Core Health
# ============================================================

subsection "Bitcoin Core"

test_command "bitcoin-cli getblockchaininfo" "bitcoin-cli -rpcuser=\${BITCOIN_RPC_USER:-btcpayrpc} -rpcpassword=\${BITCOIN_RPC_PASSWORD} -rpcport=\${BITCOIN_RPC_PORT:-8332} getblockchaininfo"
test_command "bitcoin-cli getnetworkinfo" "bitcoin-cli -rpcuser=\${BITCOIN_RPC_USER:-btcpayrpc} -rpcpassword=\${BITCOIN_RPC_PASSWORD} -rpcport=\${BITCOIN_RPC_PORT:-8332} getnetworkinfo"
test_command "bitcoin-cli getmempoolinfo" "bitcoin-cli -rpcuser=\${BITCOIN_RPC_USER:-btcpayrpc} -rpcpassword=\${BITCOIN_RPC_PASSWORD} -rpcport=\${BITCOIN_RPC_PORT:-8332} getmempoolinfo"

# ============================================================
# Monero Health
# ============================================================

subsection "Monero Daemon"

test_command "Monero RPC get_info" "curl -sf -u \${MONERO_RPC_USER:-monerorpc}:\${MONERO_RPC_PASSWORD} http://127.0.0.1:\${XMR_RPC_PORT:-18081}/json_rpc -d '{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_info\"}' -H 'Content-Type: application/json'"
test_command "Monero RPC get_height" "curl -sf -u \${MONERO_RPC_USER:-monerorpc}:\${MONERO_RPC_PASSWORD} http://127.0.0.1:\${XMR_RPC_PORT:-18081}/json_rpc -d '{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_height\"}' -H 'Content-Type: application/json'"

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
# Mempool Health
# ============================================================

subsection "Mempool Explorer"

test_http "Mempool backend info" "http://127.0.0.1:8999/api/v1/backend-info" 200
test_http "Mempool frontend (nginx)" "http://127.0.0.1:8080/" 200

# ============================================================
# Supervisor Status
# ============================================================

subsection "Supervisor"

test_command "supervisorctl status" "supervisorctl status"
test_contains "postgres running" "RUNNING" "supervisorctl status postgres"
test_contains "bitcoind running" "RUNNING" "supervisorctl status bitcoind"
test_contains "monerod running" "RUNNING" "supervisorctl status monerod"
test_contains "nbxplorer running" "RUNNING" "supervisorctl status nbxplorer"
test_contains "btcpayserver running" "RUNNING" "supervisorctl status btcpayserver"
test_contains "mempool running" "RUNNING" "supervisorctl status mempool"
test_contains "nginx running" "RUNNING" "supervisorctl status nginx"

# ============================================================
# Health Check Script
# ============================================================

subsection "Health Check Script"

test_command "health-check script passes" "sh /scripts/health-check.sh"

# ============================================================
# Log Files
# ============================================================

subsection "Log Files"

test_file "postgres log exists" "/var/log/supervisor/postgres.log"
test_file "bitcoind log exists" "/var/log/supervisor/bitcoind.log"
test_file "monerod log exists" "/var/log/supervisor/monerod.log"
test_file "nbxplorer log exists" "/var/log/supervisor/nbxplorer.log"
test_file "btcpayserver log exists" "/var/log/supervisor/btcpayserver.log"
test_file "mempool log exists" "/var/log/supervisor/mempool.log"
test_file "nginx log exists" "/var/log/supervisor/nginx.log"

# ============================================================
# Summary
# ============================================================

summary
