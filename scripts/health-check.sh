#!/bin/bash
# ============================================================
# BTCPay AIO Health Check Script
# ============================================================
# Used by Docker HEALTHCHECK to verify all services
# ============================================================

set -e

# Check PostgreSQL
pg_isready -U "${POSTGRES_USER:-btcpay}" -q || {
    echo "PostgreSQL is not ready"
    exit 1
}

# Check Bitcoin Core RPC
bitcoin-cli \
    -rpcuser="${BITCOIN_RPC_USER:-btcpayrpc}" \
    -rpcpassword="${BITCOIN_RPC_PASSWORD}" \
    -rpcport="${BITCOIN_RPC_PORT:-8332}" \
    getblockchaininfo > /dev/null 2>&1 || {
    echo "Bitcoin Core RPC is not responding"
    exit 1
}

# Check Monero RPC
curl -sf \
    -u "${MONERO_RPC_USER:-monerorpc}:${MONERO_RPC_PASSWORD}" \
    http://127.0.0.1:${XMR_RPC_PORT:-18081}/json_rpc \
    -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' \
    -H 'Content-Type: application/json' > /dev/null 2>&1 || {
    echo "Monero RPC is not responding"
    exit 1
}

# Check NBXplorer
curl -sf http://127.0.0.1:32838/health > /dev/null || {
    echo "NBXplorer health check failed"
    exit 1
}

# Check BTCPay Server
curl -sf http://127.0.0.1:49392/health > /dev/null || {
    echo "BTCPay Server health check failed"
    exit 1
}

# Check Mempool (optional - may take time to sync)
curl -sf http://127.0.0.1:8999/api/v1/backend-info > /dev/null 2>&1 || {
    echo "Mempool backend not ready (may still be syncing)"
    # Don't fail on mempool - it takes time to sync
}

echo "All services healthy"
exit 0
