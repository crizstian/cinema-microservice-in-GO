#!/bin/bash
#
# DevContainer Environment Validation Script
# Repo Type: infra-repo
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

PASS=0
FAIL=0
WARN=0

QUIET=false
JSON=false

for arg in "$@"; do
  case $arg in
    --quiet|-q) QUIET=true ;;
    --json|-j) JSON=true ;;
  esac
done

log_section() { $QUIET || echo -e "\n${BOLD}${BLUE}═══ $1 ═══${NC}"; }
log_pass() { PASS=$((PASS + 1)); $QUIET || echo -e "  ${GREEN}✓${NC} $1"; }
log_fail() { FAIL=$((FAIL + 1)); $QUIET || echo -e "  ${RED}✗${NC} $1"; }
log_warn() { WARN=$((WARN + 1)); $QUIET || echo -e "  ${YELLOW}⚠${NC} $1"; }

check_command() {
  local cmd=$1
  local version_flag=${2:---version}
  if command -v "$cmd" &> /dev/null; then
    local version=$($cmd $version_flag 2>&1 | head -1 | sed 's/^[^0-9]*//' | cut -d' ' -f1)
    log_pass "$cmd ($version)"
    # continue
  else
    log_fail "$cmd (not found)"
    # continue
  fi
}

check_env_var() {
  local var_name=$1
  local is_secret=${2:-false}
  local var_value="${!var_name:-}"
  if [ -n "$var_value" ]; then
    if [ "$is_secret" = true ]; then
      log_pass "$var_name (${var_value:0:4}****)"
    else
      log_pass "$var_name ($var_value)"
    fi
    # continue
  else
    log_fail "$var_name (not set)"
    # continue
  fi
}

test_api_auth() {
  local name=$1 url=$2 auth_header=$3 expected=${4:-200}
  local response=$(curl -s -o /dev/null -w "%{http_code}" -H "$auth_header" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [ "$response" = "$expected" ]; then
    log_pass "$name (HTTP $response)"
  elif [ "$response" = "000" ]; then
    log_fail "$name (connection failed)"
  else
    log_fail "$name (HTTP $response)"
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
    log_pass "$server_name (connected)"
  else
    log_fail "$server_name (not responding)"
  fi
}

test_npx_mcp_server() {
  local package=$1
  local server_name=$2
  local env_var=${3:-}
  local timeout=${4:-8}
  if ! command -v npx &> /dev/null; then
    log_fail "$server_name (npx not found)"
    return 0
  fi
  if [ -n "$env_var" ] && [ -z "${!env_var:-}" ]; then
    log_warn "$server_name (skipped - $env_var not set)"
    return 0
  fi
  local init_msg='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"validate","version":"1.0"},"capabilities":{}}}'
  if timeout "$timeout" sh -c "echo '$init_msg' | npx -y $package 2>/dev/null" | grep -q '"result"'; then
    log_pass "$server_name (connected)"
  else
    log_fail "$server_name (not responding)"
  fi
}

$QUIET || echo -e "${BOLD}${CYAN}"
$QUIET || echo "╔════════════════════════════════════════════════════════════════╗"
$QUIET || echo "║       DevContainer Validation - infra-repo                     ║"
$QUIET || echo "╚════════════════════════════════════════════════════════════════╝"
$QUIET || echo -e "${NC}"

# Core Tools
log_section "Core Tools"
check_command git --version
check_command docker --version
check_command gh --version
check_command task --version
check_command claude --version

# Terraform Tools
log_section "Terraform Tools"
check_command terraform version
check_command tflint --version
check_command terraform-docs --version
check_command opa version

# Kubernetes Tools
log_section "Kubernetes Tools"
check_command kubectl version
check_command helm version
check_command kustomize version

# Cloud CLIs
log_section "Cloud CLIs"
if command -v gcloud &> /dev/null; then
  GCLOUD_VER=$(gcloud version 2>/dev/null | head -1 | awk '{print $4}')
  log_pass "gcloud ($GCLOUD_VER)"
else
  log_warn "gcloud (not found)"
fi

# Check gke-gcloud-auth-plugin
if gcloud components list 2>/dev/null | grep -q "gke-gcloud-auth-plugin.*Installed"; then
  log_pass "gke-gcloud-auth-plugin (installed)"
else
  log_warn "gke-gcloud-auth-plugin (not installed)"
fi

# Environment Variables
log_section "Environment Variables"
check_env_var "HARNESS_API_KEY" true
check_env_var "HARNESS_DEFAULT_ORG_ID"
check_env_var "HARNESS_DEFAULT_PROJECT_ID"
check_env_var "HARNESS_BASE_URL"
check_env_var "GITHUB_PERSONAL_ACCESS_TOKEN" true
check_env_var "GH_TOKEN" true

# Optional cloud vars
[ -n "${GOOGLE_CLOUD_PROJECT:-}" ] && check_env_var "GOOGLE_CLOUD_PROJECT" || log_warn "GOOGLE_CLOUD_PROJECT (not set)"
[ -n "${KUBECONFIG:-}" ] && check_env_var "KUBECONFIG" || log_warn "KUBECONFIG (not set)"

# Git Configuration
log_section "Git Configuration"
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
[ -n "$GIT_NAME" ] && log_pass "git user.name ($GIT_NAME)" || log_warn "git user.name not configured"
[ -n "$GIT_EMAIL" ] && log_pass "git user.email ($GIT_EMAIL)" || log_warn "git user.email not configured"

# Docker Access
log_section "Docker Access"
if [ -S /var/run/docker.sock ]; then
  log_pass "Docker socket exists"
  docker info &> /dev/null && log_pass "Docker daemon accessible" || log_fail "Docker daemon not accessible"
else
  log_fail "Docker socket not found"
fi

# Kubernetes Connectivity
log_section "Kubernetes Connectivity"
if [ -n "${KUBECONFIG:-}" ] && [ -f "${KUBECONFIG:-}" ]; then
  log_pass "KUBECONFIG file exists"
  if kubectl cluster-info &> /dev/null; then
    CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
    log_pass "Cluster accessible (context: $CONTEXT)"
  else
    log_warn "Cluster not accessible (may need VPN or credentials)"
  fi
else
  log_warn "KUBECONFIG not configured"
fi

# GCP Authentication
log_section "GCP Authentication"
if command -v gcloud &> /dev/null; then
  ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || echo "")
  if [ -n "$ACTIVE_ACCOUNT" ]; then
    log_pass "GCP authenticated ($ACTIVE_ACCOUNT)"
  else
    log_warn "GCP not authenticated (run 'gcloud auth login')"
  fi

  ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
  if [ -n "$ACTIVE_PROJECT" ]; then
    log_pass "GCP project ($ACTIVE_PROJECT)"
  else
    log_warn "GCP project not set"
  fi
else
  log_warn "gcloud not available"
fi

# API Authentication
log_section "API Authentication"
if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  test_api_auth "GitHub API" "https://api.github.com/user" "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN"
else
  log_warn "GitHub API (skipped)"
fi

if [ -n "${HARNESS_API_KEY:-}" ] && [ -n "${HARNESS_DEFAULT_ORG_ID:-}" ]; then
  test_api_auth "Harness API" "${HARNESS_BASE_URL:-https://app.harness.io}/gateway/ng/api/organizations/${HARNESS_DEFAULT_ORG_ID}" "x-api-key: $HARNESS_API_KEY"
else
  log_warn "Harness API (skipped)"
fi

# MCP Servers (Critical)
log_section "MCP Servers (Critical)"
test_mcp_server "harness-mcp-v2" "Harness MCP"
test_npx_mcp_server "@modelcontextprotocol/server-github" "GitHub MCP" "GITHUB_PERSONAL_ACCESS_TOKEN"
test_npx_mcp_server "mcp-server-kubernetes" "Kubernetes MCP" "KUBECONFIG"

# Workspace
log_section "Workspace"
[ -d "/workspace" ] && log_pass "Workspace directory exists" || log_fail "Workspace not found"
[ -w "/workspace" ] && log_pass "Workspace is writable" || log_fail "Workspace not writable"
[ -f "/workspace/Taskfile.yml" ] && log_pass "Taskfile.yml found" || log_warn "Taskfile.yml not found"

# Summary
$QUIET || echo ""
$QUIET || echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL + WARN))

if $JSON; then
  echo "{\"pass\": $PASS, \"fail\": $FAIL, \"warn\": $WARN, \"total\": $TOTAL}"
else
  echo -e "${BOLD}Summary:${NC} ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
  [ $FAIL -eq 0 ] && echo -e "\n${GREEN}${BOLD}✓ Environment is ready!${NC}" && exit 0
  echo -e "\n${RED}${BOLD}✗ Some checks failed.${NC}" && exit 1
fi
