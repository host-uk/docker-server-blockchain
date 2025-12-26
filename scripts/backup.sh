#!/bin/bash
# ============================================================
# Docker Server Blockchain - Backup Script
# ============================================================
# Creates backups of all persistent data
# ============================================================

set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "==================================="
echo "Docker Server Blockchain Backup"
echo "Timestamp: $TIMESTAMP"
echo "==================================="

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
docker compose exec -T postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres_$TIMESTAMP.sql"
echo "PostgreSQL backup complete"

# Backup BTCPay data
echo "Backing up BTCPay data..."
docker run --rm \
    -v btcpay_datadir:/data \
    -v "$(pwd)/$BACKUP_DIR":/backup \
    alpine tar czf "/backup/btcpay_data_$TIMESTAMP.tar.gz" -C /data .
echo "BTCPay backup complete"

# Backup BTCPay plugins
echo "Backing up BTCPay plugins..."
docker run --rm \
    -v btcpay_plugins:/data \
    -v "$(pwd)/$BACKUP_DIR":/backup \
    alpine tar czf "/backup/btcpay_plugins_$TIMESTAMP.tar.gz" -C /data .
echo "BTCPay plugins backup complete"

echo ""
echo "==================================="
echo "Backup complete!"
echo "Files saved to: $BACKUP_DIR"
echo "==================================="
ls -la "$BACKUP_DIR"/*_$TIMESTAMP*
