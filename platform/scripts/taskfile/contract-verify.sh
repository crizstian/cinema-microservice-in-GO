#!/usr/bin/env bash
# Verify provider services against consumer pact files
# Usage: ./contract-verify.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

start_time=$(now)

print_banner "🔍 CONTRACT PROVIDER VERIFICATION"

declare -A provider_status provider_passed provider_failed

providers_tested=0
for svc in payment seat showtime notification; do
  [ -d "services/$svc/contracts/provider" ] || continue
  providers_tested=$((providers_tested + 1))

  echo "  Verifying: $svc"
  output=$(cd "services/$svc" && \
    PACT_PROVIDER_VERIFICATION=true PACT_DIR=../../contracts \
    go test -v ./contracts/provider/... 2>&1) || true

  parse_test_results "$output"
  provider_passed[$svc]=$TEST_PASSED
  provider_failed[$svc]=$TEST_FAILED

  if [ "${provider_failed[$svc]}" -gt 0 ]; then
    provider_status[$svc]="❌ FAIL"
  else
    provider_status[$svc]="✅ PASS"
  fi
done

duration=$(duration "$start_time")

total_passed=0 total_failed=0
for svc in payment seat showtime notification; do
  total_passed=$((total_passed + ${provider_passed[$svc]:-0}))
  total_failed=$((total_failed + ${provider_failed[$svc]:-0}))
done

final_status=$(get_status_string "$total_failed")

echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃               📊 CONTRACT VERIFICATION SUMMARY                  ┃"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
echo "┃  Provider          │ Status    │ Pass │ Fail                    ┃"
echo "┣━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━┿━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━┫"
for svc in payment seat showtime notification; do
  [ -d "services/$svc/contracts/provider" ] || continue
  printf "┃  %-17s │ %-9s │ %4s │ %-23s ┃\n" \
    "$svc" "${provider_status[$svc]}" "${provider_passed[$svc]:-0}" "${provider_failed[$svc]:-0}"
done
echo "┣━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━┷━━━━━━┷━━━━━━━━━━━━━━━━━━━━━━━━━┫"
printf "┃  Overall: %s | Passed: %d | Failed: %d | Duration: %ds        ┃\n" \
  "$final_status" "$total_passed" "$total_failed" "$duration"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
