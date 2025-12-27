#!/bin/sh
# ============================================================
# Build Tests - Verify Image Structure
# ============================================================
# Tests that run on the built image without starting services
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

section "Build Tests"

# ============================================================
# Core Binaries
# ============================================================

subsection "Core Binaries"

test_command "bitcoind installed" "which bitcoind"
test_command "bitcoin-cli installed" "which bitcoin-cli"
test_command "monerod installed" "which monerod"
test_command "monero-wallet-rpc installed" "which monero-wallet-rpc"
test_command "dotnet runtime" "dotnet --list-runtimes"
test_command "postgres installed" "which postgres"
test_command "psql installed" "which psql"
test_command "nginx installed" "which nginx"
test_command "supervisor installed" "which supervisord"
test_command "curl installed" "which curl"
test_command "bash installed" "which bash"

# ============================================================
# Application Files
# ============================================================

subsection "Application Files"

test_dir "NBXplorer directory" "/opt/nbxplorer"
test_file "NBXplorer DLL" "/opt/nbxplorer/NBXplorer.dll"
test_dir "BTCPay Server directory" "/opt/btcpayserver"
test_file "BTCPay Server DLL" "/opt/btcpayserver/BTCPayServer.dll"
test_dir "Mempool backend directory" "/opt/mempool/backend"
test_dir "Mempool frontend directory" "/opt/mempool/frontend"

# ============================================================
# Supervisor Configuration
# ============================================================

subsection "Supervisor Configuration"

test_file "supervisor main config" "/etc/supervisor/supervisord.conf"
test_dir "supervisor conf.d directory" "/etc/supervisor/conf.d"
test_file "postgres supervisor config" "/etc/supervisor/conf.d/postgres.conf"
test_file "bitcoind supervisor config" "/etc/supervisor/conf.d/bitcoind.conf"
test_file "monerod supervisor config" "/etc/supervisor/conf.d/monerod.conf"
test_file "nbxplorer supervisor config" "/etc/supervisor/conf.d/nbxplorer.conf"
test_file "btcpayserver supervisor config" "/etc/supervisor/conf.d/btcpayserver.conf"
test_file "mempool supervisor config" "/etc/supervisor/conf.d/mempool.conf"
test_file "nginx supervisor config" "/etc/supervisor/conf.d/nginx.conf"

# ============================================================
# Nginx Configuration
# ============================================================

subsection "Nginx Configuration"

test_file "nginx main config" "/etc/nginx/nginx.conf"
test_dir "nginx html directory" "/var/lib/nginx/html"

# ============================================================
# Dual-Volume Directory Structure
# ============================================================

subsection "Volume Mount Points"

test_dir "/config mount point" "/config"
test_dir "/chaindata mount point" "/chaindata"

# ============================================================
# Scripts
# ============================================================

subsection "Scripts"

test_file "entrypoint exists" "/scripts/aio-entrypoint.sh"
test_file "health-check exists" "/scripts/health-check.sh"
test_file "backup script exists" "/scripts/backup.sh"

# ============================================================
# Version Checks
# ============================================================

subsection "Version Information"

test_contains "Bitcoin Core version" "Bitcoin Core" "bitcoind --version"
test_contains "Monero version" "Monero" "monerod --version"
test_contains ".NET runtime present" "Microsoft.AspNetCore.App" "dotnet --list-runtimes"
test_contains "PostgreSQL version" "postgres" "postgres --version"
test_contains "nginx version" "nginx" "nginx -v 2>&1"

# ============================================================
# Environment Defaults
# ============================================================

subsection "Environment Variables"

test_contains "CONFIG_DIR default" "/config" "echo \${CONFIG_DIR:-/config}"
test_contains "CHAINDATA_DIR default" "/chaindata" "echo \${CHAINDATA_DIR:-/chaindata}"
test_contains "BTCPAY_NETWORK default" "mainnet" "echo \${BTCPAY_NETWORK:-mainnet}"

# ============================================================
# Summary
# ============================================================

summary
