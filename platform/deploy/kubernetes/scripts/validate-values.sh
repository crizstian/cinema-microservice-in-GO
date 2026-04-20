#!/usr/bin/env bash
# Validate values against JSON Schema before rendering
# Usage: ./validate-values.sh <service> <environment>
# Example: ./validate-values.sh movie dev
#
# Exit codes:
#   0 - Validation passed
#   1 - Validation failed
#   2 - Missing dependencies or files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

SERVICE="${1:?Usage: $0 <service> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service> <environment>}"

SCHEMA_FILE="${K8S_DIR}/schemas/values.schema.json"
MERGED_VALUES_FILE="/tmp/merged-values-${SERVICE}-${ENVIRONMENT}.json"

# Check for required tools
if ! command -v yq &> /dev/null; then
    echo "ERROR: yq is required but not installed."
    echo "Install with: brew install yq (macOS) or snap install yq (Linux)"
    exit 2
fi

if ! command -v ajv &> /dev/null; then
    echo "WARNING: ajv not found. Using basic validation only."
    USE_AJV=false
else
    USE_AJV=true
fi

echo "=== Validating values for ${SERVICE} (${ENVIRONMENT}) ==="
echo ""

# Merge values files in order (same as render does)
BASE_FILE="${K8S_DIR}/values/base.yaml"
ENV_FILE="${K8S_DIR}/values/environments/${ENVIRONMENT}.yaml"
SERVICE_FILE="${K8S_DIR}/values/services/${SERVICE}.yaml"

echo "Merging values from:"
echo "  1. ${BASE_FILE}"
echo "  2. ${ENV_FILE}"
echo "  3. ${SERVICE_FILE}"
echo ""

# Merge and convert to JSON
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1) * select(fileIndex == 2)' \
    "$BASE_FILE" "$ENV_FILE" "$SERVICE_FILE" \
    | yq -o=json > "$MERGED_VALUES_FILE"

# Add serviceName and environment if not present
yq -i ".serviceName = \"${SERVICE}\"" "$MERGED_VALUES_FILE"

echo "Merged values saved to: $MERGED_VALUES_FILE"
echo ""

# Basic validation (always runs)
echo "=== Running basic validation ==="

ERRORS=0

# Check database.replica (optional in dev for standalone MongoDB)
DB_REPLICA=$(yq -r '.database.replica // ""' "$MERGED_VALUES_FILE")
if [[ -z "$DB_REPLICA" || "$DB_REPLICA" == "null" ]]; then
    if [[ "$ENVIRONMENT" == "dev" ]]; then
        echo "INFO: database.replica is empty (standalone MongoDB for dev)"
    else
        echo "ERROR: database.replica is empty or missing (required for $ENVIRONMENT)"
        echo "  - MongoDB replica set name is required for $ENVIRONMENT"
        echo "  - Suggested fix: Set database.replica to 'rs0' in ${ENV_FILE}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "OK: database.replica = $DB_REPLICA"
fi

# Check database.servers
DB_SERVERS=$(yq '.database.servers // ""' "$MERGED_VALUES_FILE")
if [[ -z "$DB_SERVERS" || "$DB_SERVERS" == "null" ]]; then
    echo "ERROR: database.servers is empty or missing"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: database.servers = $DB_SERVERS"
fi

# Check database.user (optional in dev - no-auth mode supported)
DB_USER=$(yq '.database.user // ""' "$MERGED_VALUES_FILE")
if [[ -z "$DB_USER" || "$DB_USER" == "null" || "$DB_USER" == '""' ]]; then
    if [[ "$ENVIRONMENT" == "dev" ]]; then
        echo "INFO: database.user is empty (no-auth mode for dev)"
    else
        echo "ERROR: database.user is empty or missing (required for $ENVIRONMENT)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "OK: database.user = [REDACTED]"
fi

# Check database.password (optional in dev - no-auth mode supported)
DB_PASS=$(yq '.database.password // ""' "$MERGED_VALUES_FILE")
if [[ -z "$DB_PASS" || "$DB_PASS" == "null" || "$DB_PASS" == '""' ]]; then
    if [[ "$ENVIRONMENT" == "dev" ]]; then
        echo "INFO: database.password is empty (no-auth mode for dev)"
    else
        echo "ERROR: database.password is empty or missing (required for $ENVIRONMENT)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "OK: database.password = [REDACTED]"
fi

# Check port
PORT=$(yq '.port // 0' "$MERGED_VALUES_FILE")
if [[ "$PORT" -lt 1024 ]] || [[ "$PORT" -gt 65535 ]]; then
    echo "ERROR: port $PORT is invalid (must be 1024-65535)"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: port = $PORT"
fi

# Check namespace matches environment
NAMESPACE=$(yq -r '.namespace // ""' "$MERGED_VALUES_FILE" | tr -d '"')
EXPECTED_NS="cinema-${ENVIRONMENT}"
if [[ "$NAMESPACE" != "$EXPECTED_NS" ]]; then
    echo "ERROR: namespace '$NAMESPACE' doesn't match expected '$EXPECTED_NS'"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: namespace = $NAMESPACE"
fi

echo ""

# JSON Schema validation (if ajv available)
if [[ "$USE_AJV" == "true" ]]; then
    echo "=== Running JSON Schema validation ==="
    if ajv validate -s "$SCHEMA_FILE" -d "$MERGED_VALUES_FILE" --strict=false; then
        echo "OK: JSON Schema validation passed"
    else
        echo "ERROR: JSON Schema validation failed"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""
fi

# Summary
echo "=== Validation Summary ==="
if [[ $ERRORS -eq 0 ]]; then
    echo "PASSED: All validations passed"
    rm -f "$MERGED_VALUES_FILE"
    exit 0
else
    echo "FAILED: $ERRORS error(s) found"
    echo ""
    echo "Review merged values: $MERGED_VALUES_FILE"
    exit 1
fi
