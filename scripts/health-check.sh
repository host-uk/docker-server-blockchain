#!/bin/bash
# ============================================================
# Docker Server Blockchain - Health Check Script
# ============================================================
# Verifies all services are running correctly
# ============================================================

set -e

echo "==================================="
echo "Docker Server Blockchain Health Check"
echo "==================================="

check_service() {
    local service=$1
    local status=$(docker compose ps --format json "$service" 2>/dev/null | jq -r '.Health // .State' 2>/dev/null || echo "unknown")

    if [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
        echo "  $service: OK ($status)"
        return 0
    else
        echo "  $service: FAIL ($status)"
        return 1
    fi
}

echo ""
echo "Service Status:"
echo "---------------"

FAILED=0

check_service "btcpayserver" || FAILED=$((FAILED + 1))
check_service "nbxplorer" || FAILED=$((FAILED + 1))
check_service "bitcoind" || FAILED=$((FAILED + 1))
check_service "postgres" || FAILED=$((FAILED + 1))

echo ""

if [ $FAILED -eq 0 ]; then
    echo "All services healthy!"
    exit 0
else
    echo "$FAILED service(s) unhealthy"
    exit 1
fi
