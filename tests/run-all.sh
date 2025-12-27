#!/bin/sh
# ============================================================
# Run All Tests
# ============================================================
# Master test runner for BTCPay Server AIO
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}       BTCPay Server AIO - Test Suite                     ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}       (Bitcoin + Monero + Mempool Explorer)              ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0
SUITES_RUN=0

run_test_suite() {
    local name="$1"
    local script="$2"

    echo -e "${BLUE}Running: $name${NC}"

    if [ -f "$script" ]; then
        if sh "$script"; then
            echo -e "${GREEN}✓ $name passed${NC}"
        else
            echo -e "${RED}✗ $name failed${NC}"
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
        fi
        SUITES_RUN=$((SUITES_RUN + 1))
    else
        echo -e "${RED}Script not found: $script${NC}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi

    echo ""
}

show_help() {
    cat <<EOF
BTCPay AIO Test Suite

Usage: $0 [OPTION]

Options:
  build      Run build tests only (no services needed)
  config     Run config tests (services must be initialized)
  services   Run service tests (services must be running)
  backup     Run backup tests (services must be running)
  all        Run all tests
  help       Show this help

Test Levels:
  - build:    Tests image structure without running services
  - config:   Tests configuration after entrypoint runs
  - services: Tests running services (requires all services up)
  - backup:   Tests backup script functionality

Examples:
  $0 build                # Quick build verification
  $0 all                  # Full test suite (requires running container)

EOF
}

# Parse arguments
RUN_BUILD=false
RUN_CONFIG=false
RUN_SERVICES=false
RUN_BACKUP=false

case "${1:-build}" in
    build)
        RUN_BUILD=true
        ;;
    config)
        RUN_CONFIG=true
        ;;
    services)
        RUN_SERVICES=true
        ;;
    backup)
        RUN_BACKUP=true
        ;;
    all)
        RUN_BUILD=true
        RUN_CONFIG=true
        RUN_SERVICES=true
        RUN_BACKUP=true
        ;;
    help|--help|-h)
        show_help
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        echo ""
        show_help
        exit 1
        ;;
esac

# Run selected test suites
if [ "$RUN_BUILD" = true ]; then
    run_test_suite "Build Tests" "$SCRIPT_DIR/test-build.sh"
fi

if [ "$RUN_CONFIG" = true ]; then
    run_test_suite "Configuration Tests" "$SCRIPT_DIR/test-config.sh"
fi

if [ "$RUN_SERVICES" = true ]; then
    run_test_suite "Service Tests" "$SCRIPT_DIR/test-services.sh"
fi

if [ "$RUN_BACKUP" = true ]; then
    run_test_suite "Backup Tests" "$SCRIPT_DIR/test-backup.sh"
fi

# Final summary
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Final Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Test suites run: $SUITES_RUN"
echo "  Failed suites:   $TOTAL_FAILED"
echo ""

if [ $TOTAL_FAILED -gt 0 ]; then
    echo -e "${RED}SOME TEST SUITES FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL TEST SUITES PASSED${NC}"
    exit 0
fi
