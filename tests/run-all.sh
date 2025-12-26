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
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0
SUITES_RUN=0

run_test_suite() {
    local name="$1"
    local script="$2"

    echo -e "${BLUE}Running: $name${NC}"

    if [ -x "$script" ]; then
        if "$script"; then
            echo -e "${GREEN}✓ $name passed${NC}"
        else
            echo -e "${RED}✗ $name failed${NC}"
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
        fi
        SUITES_RUN=$((SUITES_RUN + 1))
    else
        echo -e "${RED}Script not found or not executable: $script${NC}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi

    echo ""
}

# Parse arguments
RUN_BUILD=true
RUN_CONFIG=false
RUN_SERVICES=false

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
    all)
        RUN_BUILD=true
        RUN_CONFIG=true
        RUN_SERVICES=true
        ;;
    *)
        echo "Usage: $0 [build|config|services|all]"
        echo ""
        echo "  build    - Run build tests only (default, no services needed)"
        echo "  config   - Run config tests (services must be initialized)"
        echo "  services - Run service tests (services must be running)"
        echo "  all      - Run all tests"
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
