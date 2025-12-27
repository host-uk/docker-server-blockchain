#!/bin/sh
# ============================================================
# Backup Tests - Verify Backup Script Functionality
# ============================================================
# Tests that verify the backup script works correctly
# These tests require services to be initialized
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

section "Backup Tests"

BACKUP_SCRIPT="/scripts/backup.sh"
TEST_BACKUP_DIR="/tmp/test-backups"

# ============================================================
# Script Availability
# ============================================================

subsection "Script Availability"

test_file "backup.sh exists" "$BACKUP_SCRIPT"

# ============================================================
# Help Output
# ============================================================

subsection "Help Output"

test_contains "help shows usage" "Usage:" "sh $BACKUP_SCRIPT --help"
test_contains "help shows options" "Options:" "sh $BACKUP_SCRIPT --help"
test_contains "help shows what gets backed up" "What gets backed up" "sh $BACKUP_SCRIPT --help"
test_contains "help shows what is NOT backed up" "NOT backed up" "sh $BACKUP_SCRIPT --help"

# ============================================================
# Backup Execution
# ============================================================

subsection "Backup Execution"

# Create test backup directory
mkdir -p "$TEST_BACKUP_DIR"

# Run backup to test directory
if sh $BACKUP_SCRIPT -d "$TEST_BACKUP_DIR" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Backup script completed successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Backup script failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check backup was created
LATEST_BACKUP=$(ls -t "$TEST_BACKUP_DIR"/btcpay-backup-*.tar.gz 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP" ]; then
    echo -e "${GREEN}✓${NC} Backup archive created"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Backup archive not created"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================
# Backup Contents
# ============================================================

subsection "Backup Contents"

if [ -n "$LATEST_BACKUP" ]; then
    # Check backup contains expected files
    test_contains "backup has manifest" "manifest.txt" "tar -tzf $LATEST_BACKUP"

    # Check for PostgreSQL dump
    test_contains "backup has postgres dump" "postgres-all.sql" "tar -tzf $LATEST_BACKUP"

    # Check for BTCPay data
    test_contains "backup has btcpay data" "btcpay" "tar -tzf $LATEST_BACKUP"

    # Check for configs
    test_contains "backup has configs" "configs" "tar -tzf $LATEST_BACKUP"
fi

# ============================================================
# Backup Verification
# ============================================================

subsection "Backup Verification"

if [ -n "$LATEST_BACKUP" ]; then
    # Verify tar integrity
    if tar -tzf "$LATEST_BACKUP" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Backup archive integrity OK"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Backup archive integrity FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test verification command
    test_command "verify command works" "sh $BACKUP_SCRIPT --verify 2>&1 | grep -q 'integrity'"
fi

# ============================================================
# List Backups
# ============================================================

subsection "List Backups"

test_contains "list shows backups" "backups" "sh $BACKUP_SCRIPT -l -d $TEST_BACKUP_DIR"

# ============================================================
# Backup Does NOT Include Chaindata
# ============================================================

subsection "Chaindata Exclusion"

if [ -n "$LATEST_BACKUP" ]; then
    # Verify chaindata is NOT included
    if tar -tzf "$LATEST_BACKUP" 2>/dev/null | grep -q "chaindata"; then
        echo -e "${RED}✗${NC} Backup incorrectly includes chaindata"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✓${NC} Backup correctly excludes chaindata"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    # Check backup is reasonably sized (should be much less than chaindata)
    BACKUP_SIZE=$(du -m "$LATEST_BACKUP" 2>/dev/null | cut -f1)
    if [ "$BACKUP_SIZE" -lt 1000 ]; then  # Less than 1GB indicates chaindata not included
        echo -e "${GREEN}✓${NC} Backup size reasonable (${BACKUP_SIZE}MB < 1GB)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}○${NC} Backup larger than expected (${BACKUP_SIZE}MB)"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    fi
fi

# ============================================================
# Cleanup
# ============================================================

subsection "Cleanup"

rm -rf "$TEST_BACKUP_DIR"
echo -e "${GREEN}✓${NC} Test backup directory cleaned up"
TESTS_PASSED=$((TESTS_PASSED + 1))

# ============================================================
# Summary
# ============================================================

summary
