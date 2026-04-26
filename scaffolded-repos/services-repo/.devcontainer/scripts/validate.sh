#!/bin/bash
#
# DevContainer Environment Validation Script
# Repo Type: services-repo
#
# Usage:
#   ./validate.sh           # Full validation with details
#   ./validate.sh --quiet   # Summary only
#   ./validate.sh --json    # JSON output
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Counters
PASS=0
FAIL=0
WARN=0

# Options
QUIET=false
JSON=false

for arg in "$@"; do
  case $arg in
    --quiet|-q) QUIET=true ;;
    --json|-j) JSON=true ;;
  esac
done

# ==============================================================================
# Helper Functions
# ==============================================================================

log_section() {
  $QUIET || echo -e "\n${BOLD}${BLUE}═══ $1 ═══${NC}"
}

log_pass() {
  PASS=$((PASS + 1))
  $QUIET || echo -e "  ${GREEN}✓${NC} $1"
}

log_fail() {
  FAIL=$((FAIL + 1))
  $QUIET || echo -e "  ${RED}✗${NC} $1"
}

log_warn() {
  WARN=$((WARN + 1))
  $QUIET || echo -e "  ${YELLOW}⚠${NC} $1"
}

log_info() {
  $QUIET || echo -e "  ${CYAN}ℹ${NC} $1"
}

check_command() {
  local cmd=$1
  local version_flag=${2:---version}
  if command -v "$cmd" &> /dev/null; then
    local version
    version=$($cmd $version_flag 2>&1 | head -1 | sed 's/^[^0-9]*//' | cut -d' ' -f1)
    log_pass "$cmd ($version)"
  else
    log_fail "$cmd (not found)"
  fi
}

check_env_var() {
  local var_name=$1
  local is_secret=${2:-false}
  local var_value="${!var_name:-}"

  if [ -n "$var_value" ]; then
    if [ "$is_secret" = true ]; then
      local masked="${var_value:0:4}****${var_value: -4}"
      log_pass "$var_name ($masked)"
    else
      log_pass "$var_name ($var_value)"
    fi
  else
    log_fail "$var_name (not set)"
  fi
}

test_mcp_server() {
  local server_cmd=$1
  local server_name=$2
  local timeout=${3:-5}

  if ! command -v "$server_cmd" &> /dev/null; then
    log_fail "$server_name (not installed)"
    return 0
  fi

  local init_msg='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"validate","version":"1.0"},"capabilities":{}}}'

  if timeout "$timeout" sh -c "echo '$init_msg' | $server_cmd 2>/dev/null" | grep -q '"result"'; then
    log_pass "$server_name (responding)"
  else
    log_fail "$server_name (not responding)"
  fi
}

test_npx_mcp_server() {
  local package=$1
  local server_name=$2
  local env_var=${3:-}
  local timeout=${4:-8}

  # Check if npx is available
  if ! command -v npx &> /dev/null; then
    log_fail "$server_name (npx not found)"
    return 0
  fi

  # Check if required env var is set
  if [ -n "$env_var" ] && [ -z "${!env_var:-}" ]; then
    log_warn "$server_name (skipped - $env_var not set)"
    return 0
  fi

  local init_msg='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"validate","version":"1.0"},"capabilities":{}}}'

  # Test MCP server response
  if timeout "$timeout" sh -c "echo '$init_msg' | npx -y $package 2>/dev/null" | grep -q '"result"'; then
    log_pass "$server_name (connected)"
  else
    log_fail "$server_name (not responding)"
  fi
}

test_api_auth() {
  local name=$1
  local url=$2
  local auth_header=$3
  local expected=${4:-200}
  local timeout=${5:-10}

  local response
  response=$(curl -s -o /dev/null -w "%{http_code}" -H "$auth_header" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

  if [ "$response" = "$expected" ]; then
    log_pass "$name (HTTP $response)"
  elif [ "$response" = "000" ]; then
    log_fail "$name (connection failed)"
  else
    log_fail "$name (HTTP $response, expected $expected)"
  fi
}

# ==============================================================================
# Validation Checks
# ==============================================================================

$QUIET || echo -e "${BOLD}${CYAN}"
$QUIET || echo "╔════════════════════════════════════════════════════════════════╗"
$QUIET || echo "║       DevContainer Validation - services-repo                  ║"
$QUIET || echo "╚════════════════════════════════════════════════════════════════╝"
$QUIET || echo -e "${NC}"

# -----------------------------------------------------------------------------
# 1. Core Tools
# -----------------------------------------------------------------------------
log_section "Core Tools"
check_command git --version
check_command docker --version
check_command gh --version
check_command task --version
check_command claude --version

# -----------------------------------------------------------------------------
# 2. Go Development
# -----------------------------------------------------------------------------
log_section "Go Development"
check_command go version
check_command golangci-lint --version
check_command gopls version
check_command dlv version

# Test Go environment
if command -v go &> /dev/null; then
  if go env GOPATH &> /dev/null; then
    log_pass "GOPATH configured ($(go env GOPATH))"
  else
    log_fail "GOPATH not configured"
  fi
fi

# -----------------------------------------------------------------------------
# 3. Java Development
# -----------------------------------------------------------------------------
log_section "Java Development"
check_command java -version
check_command mvn --version
check_command gradle --version

# Test JAVA_HOME
if [ -n "${JAVA_HOME:-}" ] && [ -d "$JAVA_HOME" ]; then
  log_pass "JAVA_HOME ($JAVA_HOME)"
else
  log_warn "JAVA_HOME not set or invalid"
fi

# -----------------------------------------------------------------------------
# 4. Node.js / NPM Tools
# -----------------------------------------------------------------------------
log_section "Node.js Tools"
check_command node --version
check_command npm --version
check_command spectral --version

# -----------------------------------------------------------------------------
# 5. Environment Variables
# -----------------------------------------------------------------------------
log_section "Environment Variables"
check_env_var "HARNESS_API_KEY" true
check_env_var "HARNESS_DEFAULT_ORG_ID"
check_env_var "HARNESS_DEFAULT_PROJECT_ID"
check_env_var "HARNESS_BASE_URL"
check_env_var "GITHUB_PERSONAL_ACCESS_TOKEN" true
check_env_var "GH_TOKEN" true
check_env_var "PERPLEXITY_API_KEY" true

# Optional vars
if [ -n "${GOOGLE_CLOUD_PROJECT:-}" ]; then
  check_env_var "GOOGLE_CLOUD_PROJECT"
fi

# -----------------------------------------------------------------------------
# 6. Git Configuration
# -----------------------------------------------------------------------------
log_section "Git Configuration"
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$GIT_NAME" ]; then
  log_pass "git user.name ($GIT_NAME)"
else
  log_warn "git user.name not configured"
fi

if [ -n "$GIT_EMAIL" ]; then
  log_pass "git user.email ($GIT_EMAIL)"
else
  log_warn "git user.email not configured"
fi

# -----------------------------------------------------------------------------
# 7. Docker Access
# -----------------------------------------------------------------------------
log_section "Docker Access"
if [ -S /var/run/docker.sock ]; then
  log_pass "Docker socket exists"
  if docker info &> /dev/null; then
    log_pass "Docker daemon accessible"
  else
    log_fail "Docker daemon not accessible (check permissions)"
  fi
else
  log_fail "Docker socket not found"
fi

# -----------------------------------------------------------------------------
# 8. API Authentication Tests
# -----------------------------------------------------------------------------
log_section "API Authentication"

# GitHub API
if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  test_api_auth "GitHub API" \
    "https://api.github.com/user" \
    "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN"
else
  log_warn "GitHub API (skipped - no token)"
fi

# Harness API
if [ -n "${HARNESS_API_KEY:-}" ] && [ -n "${HARNESS_DEFAULT_ORG_ID:-}" ]; then
  test_api_auth "Harness API" \
    "${HARNESS_BASE_URL:-https://app.harness.io}/gateway/ng/api/organizations/${HARNESS_DEFAULT_ORG_ID}" \
    "x-api-key: $HARNESS_API_KEY"
else
  log_warn "Harness API (skipped - no credentials)"
fi

# -----------------------------------------------------------------------------
# 9. MCP Server Tests (Critical)
# -----------------------------------------------------------------------------
log_section "MCP Servers (Critical)"

# Harness MCP - test real connectivity
test_mcp_server "harness-mcp-v2" "Harness MCP"

# GitHub MCP - test real connectivity
test_npx_mcp_server "@modelcontextprotocol/server-github" "GitHub MCP" "GITHUB_PERSONAL_ACCESS_TOKEN"

# Perplexity MCP - test real connectivity
test_npx_mcp_server "@perplexity-ai/mcp-server" "Perplexity MCP" "PERPLEXITY_API_KEY"

# -----------------------------------------------------------------------------
# 10. Workspace
# -----------------------------------------------------------------------------
log_section "Workspace"
if [ -d "/workspace" ]; then
  log_pass "Workspace directory exists"
  if [ -w "/workspace" ]; then
    log_pass "Workspace is writable"
  else
    log_fail "Workspace is not writable"
  fi
else
  log_fail "Workspace directory not found"
fi

# Check for Taskfile
if [ -f "/workspace/Taskfile.yml" ]; then
  log_pass "Taskfile.yml found"
else
  log_warn "Taskfile.yml not found"
fi

# ==============================================================================
# Summary
# ==============================================================================

$QUIET || echo ""
$QUIET || echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"

TOTAL=$((PASS + FAIL + WARN))

if $JSON; then
  echo "{\"pass\": $PASS, \"fail\": $FAIL, \"warn\": $WARN, \"total\": $TOTAL}"
else
  echo -e "${BOLD}Summary:${NC} ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"

  if [ $FAIL -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}✓ Environment is ready for development!${NC}"
    exit 0
  else
    echo -e "\n${RED}${BOLD}✗ Some checks failed. Review the issues above.${NC}"
    exit 1
  fi
fi
