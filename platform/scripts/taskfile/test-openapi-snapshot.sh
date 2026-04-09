#!/usr/bin/env bash
# OpenAPI Snapshot Tests
# Validates that OpenAPI specs haven't changed unexpectedly
# Usage: ./test-openapi-snapshot.sh [update]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

MODE="${1:-check}"
SNAPSHOT_DIR="${TEST_RESULTS_DIR}/snapshots/openapi"

print_banner "OPENAPI SNAPSHOT TESTS"

# Ensure snapshot directory exists
mkdir -p "$SNAPSHOT_DIR"

SERVICES=$(get_services)
declare -A svc_status
failed_services=""
updated_services=""

for svc in $SERVICES; do
  spec_file="services/${svc}/api/openapi.yaml"
  snapshot_file="${SNAPSHOT_DIR}/${svc}-openapi.snapshot.yaml"

  if [ ! -f "$spec_file" ]; then
    echo "  ⏭️  $svc: No OpenAPI spec found"
    svc_status[$svc]="SKIP"
    continue
  fi

  if [ "$MODE" = "update" ]; then
    # Update mode: save current spec as snapshot
    cp "$spec_file" "$snapshot_file"
    echo "  📸 $svc: Snapshot updated"
    svc_status[$svc]="UPDATED"
    updated_services="$updated_services $svc"
    continue
  fi

  # Check mode: compare with snapshot
  if [ ! -f "$snapshot_file" ]; then
    echo "  ⚠️  $svc: No snapshot found (run with 'update' to create)"
    svc_status[$svc]="NEW"
    failed_services="$failed_services $svc"
    continue
  fi

  # Compare specs (ignoring whitespace and comments)
  if diff -q <(grep -v '^#' "$spec_file" | grep -v '^$') \
              <(grep -v '^#' "$snapshot_file" | grep -v '^$') > /dev/null 2>&1; then
    echo "  $svc: Snapshot matches"
    svc_status[$svc]="PASS"
  else
    echo "  $svc: Snapshot MISMATCH"
    svc_status[$svc]="FAIL"
    failed_services="$failed_services $svc"

    # Show diff
    echo "    Differences:"
    diff -u "$snapshot_file" "$spec_file" | head -20 || true
    echo ""
  fi
done

# Generate JUnit XML report
cat > "${TEST_RESULTS_DIR}/openapi-snapshot.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="OpenAPI Snapshot Tests" tests="$(echo $SERVICES | wc -w)" failures="$(echo $failed_services | wc -w)">
  <testsuite name="openapi-snapshots" tests="$(echo $SERVICES | wc -w)">
EOF

for svc in $SERVICES; do
  status="${svc_status[$svc]:-SKIP}"
  if [ "$status" = "FAIL" ] || [ "$status" = "NEW" ]; then
    cat >> "${TEST_RESULTS_DIR}/openapi-snapshot.xml" << EOF
    <testcase name="${svc}" classname="openapi.snapshot">
      <failure message="Snapshot mismatch or missing">OpenAPI spec changed unexpectedly</failure>
    </testcase>
EOF
  else
    cat >> "${TEST_RESULTS_DIR}/openapi-snapshot.xml" << EOF
    <testcase name="${svc}" classname="openapi.snapshot"/>
EOF
  fi
done

cat >> "${TEST_RESULTS_DIR}/openapi-snapshot.xml" << EOF
  </testsuite>
</testsuites>
EOF

# Print summary
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃                         OPENAPI SNAPSHOT SUMMARY                             ┃"
echo "┣━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
echo "┃  Service          ┃ Status                                                   ┃"
echo "┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"

for svc in $SERVICES; do
  printf "┃  %-16s ┃ %-57s ┃\n" "$svc" "${svc_status[$svc]:-SKIP}"
done

echo "┗━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

if [ "$MODE" = "update" ]; then
  echo "Snapshots updated:$updated_services"
  echo "Snapshots saved to: $SNAPSHOT_DIR"
  exit 0
fi

if [ -n "$failed_services" ]; then
  echo "Snapshot mismatches:$failed_services"
  echo ""
  echo "To update snapshots, run: task test:openapi:update"
  exit 1
fi

echo "All OpenAPI snapshots match!"
