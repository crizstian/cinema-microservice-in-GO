#!/usr/bin/env bash
# Smoke test for deployed services
# Usage: ./smoke-test.sh <service> <environment> [--timeout 60]
# Example: ./smoke-test.sh movie dev --timeout 120
#
# Validates:
#   1. Pod is running and ready
#   2. Health endpoints respond correctly
#   3. Service is accessible within cluster
#
# Exit codes:
#   0 - All tests passed
#   1 - Tests failed
#   2 - Timeout waiting for deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICE="${1:?Usage: $0 <service> <environment> [--timeout SECONDS]}"
ENVIRONMENT="${2:?Usage: $0 <service> <environment> [--timeout SECONDS]}"
TIMEOUT=60

# Parse optional arguments
shift 2
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

NAMESPACE="cinema-${ENVIRONMENT}"
HEALTH_LIVE_PATH="/health/live"
HEALTH_READY_PATH="/health/ready"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SMOKE TEST: ${SERVICE} (${ENVIRONMENT})                    "
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0
WARNINGS=0

# Function to run test
run_test() {
    local name="$1"
    local command="$2"

    echo -n "Testing: ${name}... "
    if eval "$command" > /dev/null 2>&1; then
        echo "✓ PASSED"
        return 0
    else
        echo "✗ FAILED"
        return 1
    fi
}

# Function to run test with output
run_test_verbose() {
    local name="$1"
    local command="$2"

    echo "Testing: ${name}"
    if eval "$command"; then
        echo "  ✓ PASSED"
        return 0
    else
        echo "  ✗ FAILED"
        return 1
    fi
}

echo "=== Phase 1: Deployment Status ==="
echo ""

# Test 1: Check deployment exists
if ! run_test "Deployment exists" "kubectl get deployment ${SERVICE} -n ${NAMESPACE}"; then
    echo "ERROR: Deployment ${SERVICE} not found in namespace ${NAMESPACE}"
    exit 1
fi

# Test 2: Wait for rollout
echo -n "Testing: Rollout complete (timeout: ${TIMEOUT}s)... "
if kubectl rollout status deployment/"${SERVICE}" -n "${NAMESPACE}" --timeout="${TIMEOUT}s" > /dev/null 2>&1; then
    echo "✓ PASSED"
else
    echo "✗ FAILED"
    echo "ERROR: Deployment rollout did not complete within ${TIMEOUT}s"
    kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${SERVICE}" -o wide
    ERRORS=$((ERRORS + 1))
fi

# Test 3: Check pods are ready
echo ""
echo "=== Phase 2: Pod Health ==="
echo ""

READY_PODS=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${SERVICE}" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -c "True" || echo "0")
TOTAL_PODS=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${SERVICE}" --no-headers | wc -l | tr -d ' ')

echo -n "Testing: Pods ready (${READY_PODS}/${TOTAL_PODS})... "
if [[ "$READY_PODS" -gt 0 ]] && [[ "$READY_PODS" -eq "$TOTAL_PODS" ]]; then
    echo "✓ PASSED"
else
    echo "✗ FAILED"
    ERRORS=$((ERRORS + 1))
    echo ""
    echo "Pod status:"
    kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${SERVICE}" -o wide
fi

# Test 4: Check for crash loops
RESTARTS=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${SERVICE}" -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' | awk '{s+=$1} END {print s}')
echo -n "Testing: No crash loops (restarts: ${RESTARTS:-0})... "
if [[ "${RESTARTS:-0}" -lt 5 ]]; then
    echo "✓ PASSED"
else
    echo "⚠ WARNING (${RESTARTS} restarts)"
    WARNINGS=$((WARNINGS + 1))
fi

# Test 5: Check pod logs for errors
echo -n "Testing: No critical errors in logs... "
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${SERVICE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$POD_NAME" ]]; then
    CRITICAL_ERRORS=$(kubectl logs "${POD_NAME}" -n "${NAMESPACE}" --tail=50 2>/dev/null | grep -iE "(fatal|panic|critical|failed to)" | head -5 || true)
    if [[ -z "$CRITICAL_ERRORS" ]]; then
        echo "✓ PASSED"
    else
        echo "⚠ WARNING"
        echo "  Recent critical log entries:"
        echo "$CRITICAL_ERRORS" | sed 's/^/    /'
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "⚠ SKIPPED (no pods found)"
fi

echo ""
echo "=== Phase 3: Health Endpoints ==="
echo ""

# Get service port
SERVICE_PORT=$(kubectl get svc "${SERVICE}" -n "${NAMESPACE}" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "8080")

# Test 6: Liveness endpoint via port-forward
echo "Testing: Liveness endpoint (${HEALTH_LIVE_PATH})"
if [[ -n "$POD_NAME" ]]; then
    # Use kubectl exec to test from within the cluster
    LIVE_RESPONSE=$(kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- wget -qO- -T 5 "http://localhost:${SERVICE_PORT}${HEALTH_LIVE_PATH}" 2>/dev/null || echo "FAILED")
    if [[ "$LIVE_RESPONSE" != "FAILED" ]]; then
        echo "  Response: ${LIVE_RESPONSE:0:100}"
        echo "  ✓ PASSED"
    else
        echo "  ✗ FAILED (endpoint not responding)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  ⚠ SKIPPED (no pods available)"
fi

# Test 7: Readiness endpoint
echo "Testing: Readiness endpoint (${HEALTH_READY_PATH})"
if [[ -n "$POD_NAME" ]]; then
    READY_RESPONSE=$(kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- wget -qO- -T 5 "http://localhost:${SERVICE_PORT}${HEALTH_READY_PATH}" 2>/dev/null || echo "FAILED")
    if [[ "$READY_RESPONSE" != "FAILED" ]]; then
        echo "  Response: ${READY_RESPONSE:0:100}"
        echo "  ✓ PASSED"
    else
        echo "  ✗ FAILED (endpoint not responding)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  ⚠ SKIPPED (no pods available)"
fi

echo ""
echo "=== Phase 4: Service Connectivity ==="
echo ""

# Test 8: Service DNS resolution
echo -n "Testing: Service DNS resolution... "
SVC_FQDN="${SERVICE}.${NAMESPACE}.svc.cluster.local"
if [[ -n "$POD_NAME" ]]; then
    DNS_RESULT=$(kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- nslookup "${SVC_FQDN}" 2>/dev/null | grep -c "Address" || echo "0")
    if [[ "$DNS_RESULT" -gt 1 ]]; then
        echo "✓ PASSED (${SVC_FQDN})"
    else
        echo "⚠ WARNING (DNS may not be resolving)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "⚠ SKIPPED"
fi

# Test 9: Service endpoint connectivity
echo -n "Testing: Service endpoint... "
ENDPOINTS=$(kubectl get endpoints "${SERVICE}" -n "${NAMESPACE}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
if [[ -n "$ENDPOINTS" ]]; then
    ENDPOINT_COUNT=$(echo "$ENDPOINTS" | wc -w | tr -d ' ')
    echo "✓ PASSED (${ENDPOINT_COUNT} endpoint(s): ${ENDPOINTS})"
else
    echo "✗ FAILED (no endpoints)"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SMOKE TEST SUMMARY                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Service:     ${SERVICE}"
echo "Environment: ${ENVIRONMENT}"
echo "Namespace:   ${NAMESPACE}"
echo ""
echo "Results:"
echo "  Errors:   ${ERRORS}"
echo "  Warnings: ${WARNINGS}"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✓ SMOKE TEST PASSED"
    echo "═══════════════════════════════════════════════════════════════"
    exit 0
else
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✗ SMOKE TEST FAILED (${ERRORS} error(s))"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Debug commands:"
    echo "  kubectl describe deployment ${SERVICE} -n ${NAMESPACE}"
    echo "  kubectl logs -l app.kubernetes.io/name=${SERVICE} -n ${NAMESPACE} --tail=100"
    echo "  kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp'"
    exit 1
fi
