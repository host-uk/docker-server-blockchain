#!/bin/sh
# ============================================================
# Test Library - Shared Functions
# ============================================================
# Common test functions for BTCPay Server AIO testing
# ============================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ============================================================
# Output Functions
# ============================================================

section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

subsection() {
    echo ""
    echo -e "${YELLOW}─── $1 ───${NC}"
    echo ""
}

# ============================================================
# Test Functions
# ============================================================

# Test if a command succeeds
test_command() {
    local name="$1"
    local cmd="$2"

    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test if output matches expected value
test_output() {
    local name="$1"
    local expected="$2"
    local cmd="$3"

    local actual
    actual=$(eval "$cmd" 2>/dev/null)

    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name (expected: '$expected', got: '$actual')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test if output contains expected substring
test_contains() {
    local name="$1"
    local expected="$2"
    local cmd="$3"

    local actual
    actual=$(eval "$cmd" 2>&1)

    if echo "$actual" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name (expected to contain: '$expected')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test if a file exists
test_file() {
    local name="$1"
    local path="$2"

    if [ -f "$path" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name (file not found: $path)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test if a directory exists
test_dir() {
    local name="$1"
    local path="$2"

    if [ -d "$path" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name (directory not found: $path)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test if environment variable is set
test_env() {
    local name="$1"
    local var="$2"

    if [ -n "$(eval echo \$$var)" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name (env var not set: $var)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test if a port is listening
test_port() {
    local name="$1"
    local port="$2"
    local host="${3:-127.0.0.1}"

    if nc -z "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name (port $port not listening on $host)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test HTTP endpoint
test_http() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    local actual_code
    actual_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

    if [ "$actual_code" = "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name (expected: $expected_code, got: $actual_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Skip a test
test_skip() {
    local name="$1"
    local reason="$2"

    echo -e "${YELLOW}○${NC} $name (skipped: $reason)"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# ============================================================
# Summary
# ============================================================

summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE} Test Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Total:   $total"
    echo -e "  ${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo ""

    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}TESTS FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        exit 0
    fi
}
