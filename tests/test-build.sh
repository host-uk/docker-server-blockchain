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
# Binary Presence
# ============================================================

subsection "Required Binaries"

test_command "bitcoind installed" "which bitcoind"
test_command "bitcoin-cli installed" "which bitcoin-cli"
test_command "dotnet runtime" "dotnet --list-runtimes"
test_command "postgres installed" "which postgres"
test_command "psql installed" "which psql"
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

# ============================================================
# Configuration Files
# ============================================================

subsection "Configuration Files"

test_file "supervisor main config" "/etc/supervisor/supervisord.conf"
test_dir "supervisor conf.d directory" "/etc/supervisor/conf.d"
test_file "postgres supervisor config" "/etc/supervisor/conf.d/postgres.conf"
test_file "bitcoind supervisor config" "/etc/supervisor/conf.d/bitcoind.conf"
test_file "nbxplorer supervisor config" "/etc/supervisor/conf.d/nbxplorer.conf"
test_file "btcpayserver supervisor config" "/etc/supervisor/conf.d/btcpayserver.conf"

# ============================================================
# Directory Structure
# ============================================================

subsection "Directory Structure"

test_dir "/data/bitcoin" "/data/bitcoin"
test_dir "/data/bitcoin-wallet" "/data/bitcoin-wallet"
test_dir "/data/postgres" "/data/postgres"
test_dir "/data/nbxplorer" "/data/nbxplorer"
test_dir "/data/btcpay" "/data/btcpay"
test_dir "/data/btcpay-plugins" "/data/btcpay-plugins"
test_dir "/var/log/supervisor" "/var/log/supervisor"
test_dir "/run/postgresql" "/run/postgresql"

# ============================================================
# Entrypoint
# ============================================================

subsection "Entrypoint"

test_file "entrypoint exists" "/usr/local/bin/entrypoint.sh"
test_command "entrypoint executable" "test -x /usr/local/bin/entrypoint.sh"

# ============================================================
# Version Checks
# ============================================================

subsection "Version Information"

test_contains "Bitcoin Core version" "Bitcoin Core" "bitcoind --version"
test_contains ".NET runtime present" "Microsoft.AspNetCore.App" "dotnet --list-runtimes"
test_contains "PostgreSQL version" "postgres" "postgres --version"

# ============================================================
# Summary
# ============================================================

summary
