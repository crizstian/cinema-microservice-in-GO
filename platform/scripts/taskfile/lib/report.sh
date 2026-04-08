#!/usr/bin/env bash
# Test report formatting functions
# Source this file: source "$(dirname "$0")/lib/report.sh"

# ============================================================
# SINGLE SERVICE REPORT
# ============================================================

print_single_service_report() {
  local service="$1"
  local status="$2"
  local passed="$3"
  local failed="$4"
  local skipped="$5"
  local coverage="$6"
  local duration="$7"
  local total=$((passed + failed + skipped))

  echo ""
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│                    📊 TEST EXECUTION REPORT                     │"
  echo "├─────────────────────────────────────────────────────────────────┤"
  printf "│ %-20s │ %-40s │\n" "Service" "$service"
  printf "│ %-20s │ %-40s │\n" "Type" "Unit Tests"
  printf "│ %-20s │ %-40s │\n" "Status" "$status"
  echo "├─────────────────────────────────────────────────────────────────┤"
  printf "│ %-20s │ %-40s │\n" "Total Tests" "$total"
  printf "│ %-20s │ %-40s │\n" "Passed" "✅ $passed"
  printf "│ %-20s │ %-40s │\n" "Failed" "❌ $failed"
  printf "│ %-20s │ %-40s │\n" "Skipped" "⏭️  $skipped"
  echo "├─────────────────────────────────────────────────────────────────┤"
  printf "│ %-20s │ %-40s │\n" "Coverage" "$coverage"
  printf "│ %-20s │ %-40s │\n" "Duration" "${duration}s"
  echo "└─────────────────────────────────────────────────────────────────┘"
}

# ============================================================
# MULTI-SERVICE SUMMARY REPORT
# ============================================================

# Print header for multi-service report
print_multi_service_header() {
  local title="$1"
  echo ""
  echo ""
  echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
  printf "┃                        📊 %-45s ┃\n" "$title"
  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
  echo "┃  Service          │ Status    │ Pass │ Fail │ Skip │ Coverage  │ Duration  ┃"
  echo "┣━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━┿━━━━━━┿━━━━━━┿━━━━━━┿━━━━━━━━━━━┿━━━━━━━━━━━┫"
}

# Print a single service row
print_service_row() {
  local service="$1"
  local status="$2"
  local passed="$3"
  local failed="$4"
  local skipped="$5"
  local coverage="$6"
  local duration="$7"

  printf "┃  %-16s │ %-9s │ %4s │ %4s │ %4s │ %9s │ %7ss  ┃\n" \
    "$service" "$status" "$passed" "$failed" "$skipped" "$coverage" "$duration"
}

# Print footer for multi-service report
print_multi_service_footer() {
  local status="$1"
  local total_passed="$2"
  local total_failed="$3"
  local total_skipped="$4"
  local duration="$5"

  echo "┣━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━┷━━━━━━┷━━━━━━┷━━━━━━┷━━━━━━━━━━━┷━━━━━━━━━━━┫"
  printf "┃  %-16s   %-9s   %4s   %4s   %4s               %7ss  ┃\n" \
    "TOTAL" "$status" "$total_passed" "$total_failed" "$total_skipped" "$duration"
  echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
  echo ""
}

# ============================================================
# SIMPLE BOX REPORT
# ============================================================

print_simple_report() {
  local title="$1"
  local type="$2"
  local status="$3"
  local passed="$4"
  local failed="$5"
  local skipped="$6"
  local extra_label="$7"
  local extra_value="$8"
  local duration="$9"
  local total=$((passed + failed + skipped))

  echo ""
  echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
  printf "┃              📊 %-46s ┃\n" "$title"
  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
  printf "┃  %-20s │ %-40s ┃\n" "Type" "$type"
  printf "┃  %-20s │ %-40s ┃\n" "Status" "$status"
  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
  printf "┃  %-20s │ %-40s ┃\n" "Total Tests" "$total"
  printf "┃  %-20s │ %-40s ┃\n" "Passed" "✅ $passed"
  printf "┃  %-20s │ %-40s ┃\n" "Failed" "❌ $failed"
  printf "┃  %-20s │ %-40s ┃\n" "Skipped" "⏭️  $skipped"
  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
  printf "┃  %-20s │ %-40s ┃\n" "$extra_label" "$extra_value"
  printf "┃  %-20s │ %-40s ┃\n" "Duration" "${duration}s"
  echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
  echo ""
}

# ============================================================
# COVERAGE REPORT
# ============================================================

print_coverage_header() {
  echo ""
  echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
  echo "┃                   📊 COVERAGE SUMMARY REPORT                    ┃"
  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
  echo "┃  Service                                      │ Coverage       ┃"
  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━┫"
}

print_coverage_row() {
  local service="$1"
  local coverage="$2"
  local indicator="$3"

  printf "┃  %-44s │ %s %-10s ┃\n" "$service" "$indicator" "$coverage"
}

print_coverage_footer() {
  local combined="$1"
  local duration="$2"

  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┫"
  printf "┃  Combined Coverage: %-43s ┃\n" "$combined"
  echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
  printf "┃  Duration: %ds                                               ┃\n" "$duration"
  echo "┃  HTML Report: tests/test-results/coverage.html                ┃"
  echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
  echo ""
  echo "  🔗 Open: tests/test-results/coverage.html"
}

# ============================================================
# BANNERS
# ============================================================

print_banner() {
  local title="$1"
  echo ""
  echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
  printf "┃                    %-44s ┃\n" "$title"
  echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
  echo ""
}

print_section() {
  local title="$1"
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  $title"
  echo "════════════════════════════════════════════════════════════════"
}

print_phase() {
  local title="$1"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $title"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
