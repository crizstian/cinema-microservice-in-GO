#!/bin/bash
#
# scaffold-devcontainer.sh
#
# Generates .devcontainer/ configuration for the 3 monorepos:
#   - services-repo: Go, Java, Python development
#   - platform-repo: CI/CD, Docker, YAML tooling
#   - infra-repo: Terraform, Kubernetes, Helm
#
# Usage:
#   ./scaffold-devcontainer.sh <repo-type> <output-dir>
#   ./scaffold-devcontainer.sh all <output-dir>
#
# Examples:
#   ./scaffold-devcontainer.sh services ./services-repo
#   ./scaffold-devcontainer.sh platform ./platform-repo
#   ./scaffold-devcontainer.sh infra ./infra-repo
#   ./scaffold-devcontainer.sh all ./repos
#
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
  cat << EOF
Usage: $0 <repo-type> <output-dir>

Repo types:
  services   - Go, Java, Python development environment
  platform   - CI/CD, Docker, YAML tooling environment
  infra      - Terraform, Kubernetes, Helm environment
  all        - Generate all three repo types

Examples:
  $0 services ./services-repo
  $0 all ./repos

EOF
  exit 1
}

# ==============================================================================
# Common Files
# ==============================================================================

generate_env_template() {
  local output_dir=$1
  local repo_type=$2

  cat > "$output_dir/.devcontainer/.env.template" << 'EOF'
# ==============================================================================
# DevContainer Environment Variables Template
# ==============================================================================
# Copy this file to .env and fill in your values:
#   cp .env.template .env
#
# NEVER commit .env to git - it contains secrets!
# ==============================================================================

# ------------------------------------------------------------------------------
# Harness Configuration
# ------------------------------------------------------------------------------
HARNESS_API_KEY=
HARNESS_DEFAULT_ORG_ID=
HARNESS_DEFAULT_PROJECT_ID=
HARNESS_BASE_URL=https://app.harness.io
HARNESS_TOOLSETS=pipelines,services,connectors,logs,delegates

# ------------------------------------------------------------------------------
# GitHub Configuration
# ------------------------------------------------------------------------------
GITHUB_PERSONAL_ACCESS_TOKEN=
GH_TOKEN=

# ------------------------------------------------------------------------------
# AI Tools
# ------------------------------------------------------------------------------
PERPLEXITY_API_KEY=

# ------------------------------------------------------------------------------
# Google Cloud (optional)
# ------------------------------------------------------------------------------
GOOGLE_CLOUD_PROJECT=
GOOGLE_APPLICATION_CREDENTIALS=/home/devuser/.config/gcloud/application_default_credentials.json
CLOUD_ML_REGION=us-east5

# ------------------------------------------------------------------------------
# Kubernetes (optional)
# ------------------------------------------------------------------------------
KUBECONFIG=/home/devuser/.kube/config

# ------------------------------------------------------------------------------
# Claude Code with Vertex AI (optional)
# ------------------------------------------------------------------------------
CLAUDE_CODE_USE_VERTEX=0
ANTHROPIC_VERTEX_PROJECT_ID=

# ------------------------------------------------------------------------------
# Git Configuration
# ------------------------------------------------------------------------------
GIT_USER_NAME=
GIT_USER_EMAIL=

# ------------------------------------------------------------------------------
# ShiftLeft Security (optional)
# ------------------------------------------------------------------------------
SHIFTLEFT_ACCESS_TOKEN=
SHIFTLEFT_ORG_ID=
EOF
}

generate_post_create_script() {
  local output_dir=$1
  local repo_type=$2

  cat > "$output_dir/.devcontainer/scripts/post-create.sh" << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "[post-create] Setting up development environment..."
echo "=========================================="

# Git configuration
if [ -n "$GIT_USER_NAME" ]; then
  git config --global user.name "$GIT_USER_NAME"
  echo "[post-create] Git user.name set to: $GIT_USER_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
  echo "[post-create] Git user.email set to: $GIT_USER_EMAIL"
fi

# GitHub CLI authentication
if [ -n "$GH_TOKEN" ]; then
  echo "[post-create] Authenticating GitHub CLI..."
  echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null || echo "[post-create] GitHub CLI auth skipped"
fi

# ShiftLeft CLI (optional)
if [ -n "$SHIFTLEFT_ACCESS_TOKEN" ] && [ -n "$SHIFTLEFT_ORG_ID" ]; then
  if command -v sl &> /dev/null; then
    echo "[post-create] Authenticating ShiftLeft..."
    sl auth --token "$SHIFTLEFT_ACCESS_TOKEN" --org "$SHIFTLEFT_ORG_ID" || true
  fi
fi

echo "=========================================="
echo "[post-create] Setup complete!"
echo "=========================================="
EOF
  chmod +x "$output_dir/.devcontainer/scripts/post-create.sh"
}

generate_post_start_script() {
  local output_dir=$1
  local repo_type=$2

  cat > "$output_dir/.devcontainer/scripts/post-start.sh" << 'SCRIPT_EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "[post-start] Initializing environment..."
echo "=========================================="

# Docker socket permissions
if [ -S /var/run/docker.sock ]; then
  echo "[post-start] Configuring Docker socket permissions..."
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  if ! getent group docker >/dev/null 2>&1; then
    sudo addgroup -g "$DOCKER_GID" docker 2>/dev/null || true
  fi
  sudo addgroup devuser docker 2>/dev/null || true
  sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# Run validation
if [ -f ".devcontainer/scripts/validate.sh" ]; then
  echo "[post-start] Running environment validation..."
  bash .devcontainer/scripts/validate.sh --quiet || true
fi

echo "=========================================="
echo "[post-start] Environment ready!"
echo "[post-start] Run 'task validate:env' for detailed validation"
echo "=========================================="
SCRIPT_EOF
  chmod +x "$output_dir/.devcontainer/scripts/post-start.sh"
}

# ==============================================================================
# Validation Script Generators (per repo type)
# ==============================================================================

generate_services_validation_script() {
  local output_dir=$1
  log_info "Generating validation script for services-repo"

  cat > "$output_dir/.devcontainer/scripts/validate.sh" << 'SCRIPT_EOF'
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
SCRIPT_EOF
  chmod +x "$output_dir/.devcontainer/scripts/validate.sh"
}

generate_platform_validation_script() {
  local output_dir=$1
  log_info "Generating validation script for platform-repo"

  cat > "$output_dir/.devcontainer/scripts/validate.sh" << 'SCRIPT_EOF'
#!/bin/bash
#
# DevContainer Environment Validation Script
# Repo Type: platform-repo
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
$QUIET || echo "║       DevContainer Validation - platform-repo                  ║"
$QUIET || echo "╚════════════════════════════════════════════════════════════════╝"
$QUIET || echo -e "${NC}"

# Core Tools
log_section "Core Tools"
check_command git --version
check_command docker --version
check_command gh --version
check_command task --version
check_command claude --version

# CI/CD Tools
log_section "CI/CD & YAML Tools"
check_command yq --version
check_command jq --version
check_command yamllint --version
check_command shellcheck --version
check_command opa version

# Node.js Tools
log_section "Node.js Tools"
check_command node --version
check_command npm --version
check_command spectral --version
check_command ajv --version

# Environment Variables
log_section "Environment Variables"
check_env_var "HARNESS_API_KEY" true
check_env_var "HARNESS_DEFAULT_ORG_ID"
check_env_var "HARNESS_DEFAULT_PROJECT_ID"
check_env_var "HARNESS_BASE_URL"
check_env_var "HARNESS_TOOLSETS"
check_env_var "GITHUB_PERSONAL_ACCESS_TOKEN" true
check_env_var "GH_TOKEN" true

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
SCRIPT_EOF
  chmod +x "$output_dir/.devcontainer/scripts/validate.sh"
}

generate_infra_validation_script() {
  local output_dir=$1
  log_info "Generating validation script for infra-repo"

  cat > "$output_dir/.devcontainer/scripts/validate.sh" << 'SCRIPT_EOF'
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
SCRIPT_EOF
  chmod +x "$output_dir/.devcontainer/scripts/validate.sh"
}

generate_gitignore_entry() {
  local output_dir=$1

  # Add .env to .gitignore if not already present
  if [ -f "$output_dir/.gitignore" ]; then
    if ! grep -q "^\.devcontainer/\.env$" "$output_dir/.gitignore"; then
      echo "" >> "$output_dir/.gitignore"
      echo "# DevContainer secrets (never commit)" >> "$output_dir/.gitignore"
      echo ".devcontainer/.env" >> "$output_dir/.gitignore"
    fi
  else
    cat > "$output_dir/.gitignore" << 'EOF'
# DevContainer secrets (never commit)
.devcontainer/.env
EOF
  fi
}

# ==============================================================================
# Taskfile Generators
# ==============================================================================

generate_services_taskfile() {
  local output_dir=$1
  log_info "Generating Taskfile.yml for services-repo"

  cat > "$output_dir/Taskfile.yml" << 'EOF'
# https://taskfile.dev
version: "3"

vars:
  SERVICE: '{{.SERVICE | default "booking"}}'
  COVERAGE_THRESHOLD: '{{.COVERAGE_THRESHOLD | default "80"}}'

tasks:
  # ============================================================================
  # DEFAULT
  # ============================================================================
  default:
    desc: "Show available tasks"
    cmds: ["task --list"]

  # ============================================================================
  # CODE QUALITY
  # ============================================================================
  quality:
    desc: "Run all quality checks: task quality SERVICE=booking"
    cmds:
      - task: quality:lint
      - task: quality:vet
      - task: quality:complexity

  quality:lint:
    desc: "Run golangci-lint: task quality:lint SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - golangci-lint run ./... --timeout 5m

  quality:vet:
    desc: "Run go vet: task quality:vet SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go vet ./...

  quality:complexity:
    desc: "Check cyclomatic complexity: task quality:complexity SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - |
        if command -v gocyclo &> /dev/null; then
          gocyclo -over 15 . || echo "High complexity detected"
        else
          echo "gocyclo not installed, skipping"
        fi

  quality:all:
    desc: "Run quality checks on all services"
    cmds:
      - |
        for svc in services/*/; do
          svc_name=$(basename "$svc")
          echo "=== Quality: $svc_name ==="
          task quality SERVICE="$svc_name" || true
        done

  # ============================================================================
  # TESTS
  # ============================================================================
  test:
    desc: "Run unit tests: task test SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go test -v -race -coverprofile=coverage.out ./...

  test:coverage:
    desc: "Run tests with coverage report: task test:coverage SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go test -v -race -coverprofile=coverage.out ./...
      - go tool cover -func=coverage.out
      - |
        COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | tr -d '%')
        echo "Coverage: ${COVERAGE}%"
        if (( $(echo "$COVERAGE < {{.COVERAGE_THRESHOLD}}" | bc -l) )); then
          echo "ERROR: Coverage ${COVERAGE}% is below threshold {{.COVERAGE_THRESHOLD}}%"
          exit 1
        fi

  test:html:
    desc: "Generate HTML coverage report: task test:html SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go test -coverprofile=coverage.out ./...
      - go tool cover -html=coverage.out -o coverage.html
      - echo "Coverage report: services/{{.SERVICE}}/coverage.html"

  test:all:
    desc: "Run tests for all services"
    cmds:
      - |
        for svc in services/*/; do
          svc_name=$(basename "$svc")
          echo "=== Testing: $svc_name ==="
          task test SERVICE="$svc_name" || true
        done

  test:benchmark:
    desc: "Run benchmark tests: task test:benchmark SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go test -bench=. -benchmem ./...

  # ============================================================================
  # BUILD
  # ============================================================================
  build:
    desc: "Build binary: task build SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/{{.SERVICE}} ./cmd/{{.SERVICE}}

  build:docker:
    desc: "Build Docker image: task build:docker SERVICE=booking [VERSION=latest]"
    vars:
      VERSION: '{{.VERSION | default "latest"}}'
    cmds:
      - docker build -t {{.SERVICE}}:{{.VERSION}} -f services/{{.SERVICE}}/Dockerfile services/{{.SERVICE}}

  build:all:
    desc: "Build all services"
    cmds:
      - |
        for svc in services/*/; do
          svc_name=$(basename "$svc")
          echo "=== Building: $svc_name ==="
          task build SERVICE="$svc_name" || true
        done

  # ============================================================================
  # RUN
  # ============================================================================
  run:
    desc: "Run service locally: task run SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go run ./cmd/{{.SERVICE}}

  run:docker:
    desc: "Run service in Docker: task run:docker SERVICE=booking"
    cmds:
      - task: build:docker
      - docker run --rm -p 8080:8080 {{.SERVICE}}:latest

  # ============================================================================
  # DEPENDENCIES
  # ============================================================================
  deps:
    desc: "Download dependencies: task deps SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go mod download
      - go mod tidy

  deps:update:
    desc: "Update dependencies: task deps:update SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - go get -u ./...
      - go mod tidy

  deps:all:
    desc: "Download dependencies for all services"
    cmds:
      - |
        for svc in services/*/; do
          svc_name=$(basename "$svc")
          echo "=== Deps: $svc_name ==="
          task deps SERVICE="$svc_name" || true
        done

  # ============================================================================
  # OPENAPI
  # ============================================================================
  openapi:lint:
    desc: "Lint OpenAPI spec: task openapi:lint SERVICE=booking"
    cmds:
      - |
        SPEC="services/{{.SERVICE}}/api/openapi.yaml"
        if [ -f "$SPEC" ]; then
          spectral lint "$SPEC" || true
        else
          echo "No OpenAPI spec found: $SPEC"
        fi

  openapi:generate:
    desc: "Generate code from OpenAPI spec: task openapi:generate SERVICE=booking"
    cmds:
      - |
        SPEC="services/{{.SERVICE}}/api/openapi.yaml"
        if [ -f "$SPEC" ]; then
          echo "OpenAPI spec found: $SPEC"
          # Add your oapi-codegen or similar command here
        else
          echo "No OpenAPI spec found: $SPEC"
        fi

  # ============================================================================
  # JAVA SERVICES
  # ============================================================================
  java:test:
    desc: "Run Java tests: task java:test SERVICE=analytics"
    dir: services/{{.SERVICE}}
    cmds:
      - |
        if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
          ./gradlew test --no-daemon
        elif [ -f "pom.xml" ]; then
          mvn test
        else
          echo "No Java build file found"
        fi

  java:build:
    desc: "Build Java service: task java:build SERVICE=analytics"
    dir: services/{{.SERVICE}}
    cmds:
      - |
        if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
          ./gradlew build --no-daemon
        elif [ -f "pom.xml" ]; then
          mvn package -DskipTests
        else
          echo "No Java build file found"
        fi

  # ============================================================================
  # VALIDATE (CI-like)
  # ============================================================================
  validate:
    desc: "Full validation (quality + tests): task validate SERVICE=booking"
    cmds:
      - task: quality
        vars: { SERVICE: "{{.SERVICE}}" }
      - task: test
        vars: { SERVICE: "{{.SERVICE}}" }

  validate:all:
    desc: "Validate all services"
    cmds:
      - task: quality:all
      - task: test:all

  # ============================================================================
  # CLEAN
  # ============================================================================
  clean:
    desc: "Clean build artifacts: task clean SERVICE=booking"
    dir: services/{{.SERVICE}}
    cmds:
      - rm -rf bin/ coverage.out coverage.html
      - go clean -cache

  clean:all:
    desc: "Clean all services"
    cmds:
      - |
        for svc in services/*/; do
          svc_name=$(basename "$svc")
          echo "=== Cleaning: $svc_name ==="
          task clean SERVICE="$svc_name" || true
        done

  # ============================================================================
  # ENVIRONMENT VALIDATION
  # ============================================================================
  validate:env:
    desc: "Validate devcontainer environment (tools, auth, MCP)"
    cmds:
      - bash .devcontainer/scripts/validate.sh

  validate:env:json:
    desc: "Validate environment (JSON output)"
    cmds:
      - bash .devcontainer/scripts/validate.sh --json

  validate:env:quiet:
    desc: "Validate environment (quiet mode)"
    cmds:
      - bash .devcontainer/scripts/validate.sh --quiet
EOF
}

generate_platform_taskfile() {
  local output_dir=$1
  log_info "Generating Taskfile.yml for platform-repo"

  cat > "$output_dir/Taskfile.yml" << 'EOF'
# https://taskfile.dev
version: "3"

vars:
  PIPELINE: '{{.PIPELINE | default ""}}'
  TEMPLATE: '{{.TEMPLATE | default ""}}'

tasks:
  # ============================================================================
  # DEFAULT
  # ============================================================================
  default:
    desc: "Show available tasks"
    cmds: ["task --list"]

  # ============================================================================
  # YAML VALIDATION
  # ============================================================================
  lint:yaml:
    desc: "Lint all YAML files"
    cmds:
      - yamllint -d relaxed .harness/ || true
      - yamllint -d relaxed .github/ 2>/dev/null || true

  lint:harness:
    desc: "Validate Harness pipeline YAML"
    cmds:
      - |
        for f in .harness/pipelines/**/*.yaml; do
          echo "Validating: $f"
          yq eval '.' "$f" > /dev/null || echo "Invalid YAML: $f"
        done

  lint:templates:
    desc: "Validate Harness template YAML"
    cmds:
      - |
        for f in .harness/templates/**/*.yaml; do
          echo "Validating: $f"
          yq eval '.' "$f" > /dev/null || echo "Invalid YAML: $f"
        done

  lint:all:
    desc: "Run all linting"
    cmds:
      - task: lint:yaml
      - task: lint:harness
      - task: lint:templates
      - task: lint:shell

  # ============================================================================
  # SHELL SCRIPTS
  # ============================================================================
  lint:shell:
    desc: "Lint shell scripts with shellcheck"
    cmds:
      - |
        find . -name "*.sh" -type f | while read script; do
          echo "Checking: $script"
          shellcheck "$script" || true
        done

  # ============================================================================
  # OPA POLICIES
  # ============================================================================
  policy:test:
    desc: "Test OPA policies"
    cmds:
      - |
        if [ -d ".harness/policies" ]; then
          for policy in .harness/policies/*.rego; do
            echo "Testing: $policy"
            opa test "$policy" || true
          done
        else
          echo "No policies directory found"
        fi

  policy:eval:
    desc: "Evaluate OPA policy against input: task policy:eval POLICY=security INPUT=pipeline.json"
    vars:
      POLICY: '{{.POLICY | default ""}}'
      INPUT: '{{.INPUT | default ""}}'
    cmds:
      - |
        if [ -z "{{.POLICY}}" ] || [ -z "{{.INPUT}}" ]; then
          echo "Usage: task policy:eval POLICY=<policy.rego> INPUT=<input.json>"
          exit 1
        fi
        opa eval -i "{{.INPUT}}" -d "{{.POLICY}}" "data"

  # ============================================================================
  # SPECTRAL (OpenAPI)
  # ============================================================================
  spectral:lint:
    desc: "Lint OpenAPI specs with Spectral"
    cmds:
      - |
        for spec in $(find . -name "openapi.yaml" -o -name "openapi.yml"); do
          echo "Linting: $spec"
          spectral lint "$spec" || true
        done

  # ============================================================================
  # DOCKER
  # ============================================================================
  docker:lint:
    desc: "Lint Dockerfiles"
    cmds:
      - |
        for df in $(find . -name "Dockerfile*" -type f); do
          echo "Checking: $df"
          # Use hadolint if available
          if command -v hadolint &> /dev/null; then
            hadolint "$df" || true
          else
            echo "hadolint not installed, skipping"
          fi
        done

  docker:build:base:
    desc: "Build base devcontainer image"
    cmds:
      - |
        if [ -f "tooling/devcontainer/Dockerfile.base" ]; then
          docker build -t platform/devcontainer-base:latest -f tooling/devcontainer/Dockerfile.base tooling/devcontainer/
        else
          echo "No base Dockerfile found"
        fi

  # ============================================================================
  # HARNESS PIPELINES
  # ============================================================================
  pipeline:list:
    desc: "List all pipelines"
    cmds:
      - |
        echo "=== Pipelines ==="
        find .harness/pipelines -name "*.yaml" -type f | while read f; do
          name=$(yq '.pipeline.name // .name // "unknown"' "$f" 2>/dev/null)
          echo "  - $f: $name"
        done

  pipeline:validate:
    desc: "Validate pipeline structure: task pipeline:validate PIPELINE=CI-Unified"
    cmds:
      - |
        PIPELINE_FILE=$(find .harness/pipelines -name "*{{.PIPELINE}}*.yaml" | head -1)
        if [ -z "$PIPELINE_FILE" ]; then
          echo "Pipeline not found: {{.PIPELINE}}"
          exit 1
        fi
        echo "Validating: $PIPELINE_FILE"
        yq eval '.' "$PIPELINE_FILE" > /dev/null
        echo "Pipeline is valid YAML"

  template:list:
    desc: "List all templates"
    cmds:
      - |
        echo "=== Templates ==="
        find .harness/templates -name "*.yaml" -type f 2>/dev/null | while read f; do
          name=$(yq '.template.name // .name // "unknown"' "$f" 2>/dev/null)
          type=$(yq '.template.type // "unknown"' "$f" 2>/dev/null)
          echo "  - $f: $name ($type)"
        done

  # ============================================================================
  # DOCUMENTATION
  # ============================================================================
  docs:serve:
    desc: "Serve documentation locally (requires mkdocs)"
    cmds:
      - |
        if command -v mkdocs &> /dev/null; then
          mkdocs serve
        else
          echo "mkdocs not installed. Install with: pip install mkdocs"
        fi

  # ============================================================================
  # CI SIMULATION
  # ============================================================================
  ci:validate:
    desc: "Simulate CI validation stage"
    cmds:
      - task: lint:all
      - task: policy:test

  ci:full:
    desc: "Simulate full CI pipeline"
    cmds:
      - task: ci:validate
      - task: docker:lint

  # ============================================================================
  # CLEAN
  # ============================================================================
  clean:
    desc: "Clean generated files"
    cmds:
      - rm -rf dist/ build/ .task/
      - find . -name "*.bak" -delete

  # ============================================================================
  # ENVIRONMENT VALIDATION
  # ============================================================================
  validate:env:
    desc: "Validate devcontainer environment (tools, auth, MCP)"
    cmds:
      - bash .devcontainer/scripts/validate.sh

  validate:env:json:
    desc: "Validate environment (JSON output)"
    cmds:
      - bash .devcontainer/scripts/validate.sh --json

  validate:env:quiet:
    desc: "Validate environment (quiet mode)"
    cmds:
      - bash .devcontainer/scripts/validate.sh --quiet
EOF
}

generate_infra_taskfile() {
  local output_dir=$1
  log_info "Generating Taskfile.yml for infra-repo"

  cat > "$output_dir/Taskfile.yml" << 'EOF'
# https://taskfile.dev
version: "3"

vars:
  ENV: '{{.ENV | default "dev"}}'
  COMPONENT: '{{.COMPONENT | default ""}}'
  NAMESPACE: 'cinema-{{.ENV}}'

tasks:
  # ============================================================================
  # DEFAULT
  # ============================================================================
  default:
    desc: "Show available tasks"
    cmds: ["task --list"]

  # ============================================================================
  # TERRAFORM
  # ============================================================================
  tf:init:
    desc: "Initialize Terraform: task tf:init ENV=dev"
    dir: terraform/environments/{{.ENV}}
    cmds:
      - terraform init

  tf:validate:
    desc: "Validate Terraform: task tf:validate ENV=dev"
    dir: terraform/environments/{{.ENV}}
    cmds:
      - terraform validate

  tf:plan:
    desc: "Plan Terraform changes: task tf:plan ENV=dev"
    dir: terraform/environments/{{.ENV}}
    cmds:
      - terraform plan -out=tfplan

  tf:apply:
    desc: "Apply Terraform changes: task tf:apply ENV=dev"
    dir: terraform/environments/{{.ENV}}
    cmds:
      - terraform apply tfplan

  tf:destroy:
    desc: "Destroy Terraform resources: task tf:destroy ENV=dev"
    dir: terraform/environments/{{.ENV}}
    cmds:
      - terraform destroy

  tf:fmt:
    desc: "Format Terraform files"
    cmds:
      - terraform fmt -recursive terraform/

  tf:lint:
    desc: "Lint Terraform with tflint"
    cmds:
      - |
        for dir in terraform/environments/*/; do
          echo "=== Linting: $dir ==="
          cd "$dir" && tflint --init && tflint || true
          cd - > /dev/null
        done

  tf:docs:
    desc: "Generate Terraform docs"
    cmds:
      - |
        for dir in terraform/modules/*/; do
          echo "=== Documenting: $dir ==="
          terraform-docs markdown table "$dir" > "$dir/README.md" || true
        done

  tf:security:
    desc: "Security scan with tfsec or checkov"
    cmds:
      - |
        if command -v tfsec &> /dev/null; then
          tfsec terraform/
        elif command -v checkov &> /dev/null; then
          checkov -d terraform/
        else
          echo "No security scanner found (tfsec or checkov)"
        fi

  # ============================================================================
  # KUBERNETES
  # ============================================================================
  k8s:context:
    desc: "Show current kubectl context"
    cmds:
      - kubectl config current-context
      - kubectl cluster-info

  k8s:ns:
    desc: "List namespaces"
    cmds:
      - kubectl get namespaces

  k8s:pods:
    desc: "List pods in namespace: task k8s:pods ENV=dev"
    cmds:
      - kubectl get pods -n {{.NAMESPACE}} -o wide

  k8s:services:
    desc: "List services in namespace: task k8s:services ENV=dev"
    cmds:
      - kubectl get svc -n {{.NAMESPACE}}

  k8s:deployments:
    desc: "List deployments in namespace: task k8s:deployments ENV=dev"
    cmds:
      - kubectl get deployments -n {{.NAMESPACE}}

  k8s:logs:
    desc: "Get logs for a deployment: task k8s:logs COMPONENT=booking ENV=dev"
    cmds:
      - kubectl logs -n {{.NAMESPACE}} -l app.kubernetes.io/name={{.COMPONENT}} --tail=100

  k8s:exec:
    desc: "Exec into a pod: task k8s:exec COMPONENT=booking ENV=dev"
    cmds:
      - |
        POD=$(kubectl get pods -n {{.NAMESPACE}} -l app.kubernetes.io/name={{.COMPONENT}} -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -it -n {{.NAMESPACE}} "$POD" -- /bin/sh

  k8s:describe:
    desc: "Describe deployment: task k8s:describe COMPONENT=booking ENV=dev"
    cmds:
      - kubectl describe deployment {{.COMPONENT}} -n {{.NAMESPACE}}

  k8s:rollout:status:
    desc: "Check rollout status: task k8s:rollout:status COMPONENT=booking ENV=dev"
    cmds:
      - kubectl rollout status deployment/{{.COMPONENT}} -n {{.NAMESPACE}}

  k8s:rollout:restart:
    desc: "Restart deployment: task k8s:rollout:restart COMPONENT=booking ENV=dev"
    cmds:
      - kubectl rollout restart deployment/{{.COMPONENT}} -n {{.NAMESPACE}}

  k8s:rollout:undo:
    desc: "Rollback deployment: task k8s:rollout:undo COMPONENT=booking ENV=dev"
    cmds:
      - kubectl rollout undo deployment/{{.COMPONENT}} -n {{.NAMESPACE}}

  # ============================================================================
  # HELM
  # ============================================================================
  helm:repos:
    desc: "Add common Helm repos"
    cmds:
      - helm repo add bitnami https://charts.bitnami.com/bitnami
      - helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
      - helm repo add jetstack https://charts.jetstack.io
      - helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      - helm repo update

  helm:list:
    desc: "List Helm releases: task helm:list ENV=dev"
    cmds:
      - helm list -n {{.NAMESPACE}}

  helm:template:
    desc: "Template Helm chart: task helm:template COMPONENT=booking ENV=dev"
    cmds:
      - |
        if [ -d "kubernetes/charts/{{.COMPONENT}}" ]; then
          helm template {{.COMPONENT}} kubernetes/charts/{{.COMPONENT}} \
            -f kubernetes/values/{{.ENV}}/{{.COMPONENT}}.yaml
        else
          echo "Chart not found: kubernetes/charts/{{.COMPONENT}}"
        fi

  helm:install:
    desc: "Install Helm release: task helm:install COMPONENT=booking ENV=dev"
    cmds:
      - |
        helm upgrade --install {{.COMPONENT}} kubernetes/charts/{{.COMPONENT}} \
          -n {{.NAMESPACE}} \
          -f kubernetes/values/{{.ENV}}/{{.COMPONENT}}.yaml

  helm:uninstall:
    desc: "Uninstall Helm release: task helm:uninstall COMPONENT=booking ENV=dev"
    cmds:
      - helm uninstall {{.COMPONENT}} -n {{.NAMESPACE}}

  # ============================================================================
  # KUSTOMIZE
  # ============================================================================
  kustomize:build:
    desc: "Build kustomize manifests: task kustomize:build ENV=dev"
    cmds:
      - kustomize build kubernetes/overlays/{{.ENV}}

  kustomize:apply:
    desc: "Apply kustomize manifests: task kustomize:apply ENV=dev"
    cmds:
      - kustomize build kubernetes/overlays/{{.ENV}} | kubectl apply -f -

  kustomize:diff:
    desc: "Diff kustomize manifests: task kustomize:diff ENV=dev"
    cmds:
      - kustomize build kubernetes/overlays/{{.ENV}} | kubectl diff -f -

  # ============================================================================
  # OPA POLICIES
  # ============================================================================
  policy:test:
    desc: "Test OPA policies"
    cmds:
      - |
        if [ -d "policies" ]; then
          opa test policies/ -v
        else
          echo "No policies directory found"
        fi

  policy:check:
    desc: "Check manifest against policies: task policy:check MANIFEST=deployment.yaml"
    vars:
      MANIFEST: '{{.MANIFEST | default ""}}'
    cmds:
      - |
        if [ -z "{{.MANIFEST}}" ]; then
          echo "Usage: task policy:check MANIFEST=<manifest.yaml>"
          exit 1
        fi
        conftest test "{{.MANIFEST}}" -p policies/

  # ============================================================================
  # GCLOUD
  # ============================================================================
  gcp:project:
    desc: "Show current GCP project"
    cmds:
      - gcloud config get-value project
      - gcloud config get-value account

  gcp:clusters:
    desc: "List GKE clusters"
    cmds:
      - gcloud container clusters list

  gcp:credentials:
    desc: "Get GKE credentials: task gcp:credentials CLUSTER=my-cluster ZONE=us-east5-a"
    vars:
      CLUSTER: '{{.CLUSTER | default ""}}'
      ZONE: '{{.ZONE | default "us-east5-a"}}'
    cmds:
      - gcloud container clusters get-credentials {{.CLUSTER}} --zone {{.ZONE}}

  # ============================================================================
  # VALIDATE
  # ============================================================================
  validate:
    desc: "Run all validations"
    cmds:
      - task: tf:validate
      - task: tf:lint
      - task: policy:test

  validate:manifests:
    desc: "Validate Kubernetes manifests"
    cmds:
      - |
        for manifest in $(find kubernetes -name "*.yaml" -type f); do
          echo "Validating: $manifest"
          kubectl apply --dry-run=client -f "$manifest" 2>/dev/null || echo "  -> Invalid or needs cluster"
        done

  # ============================================================================
  # CLEAN
  # ============================================================================
  clean:
    desc: "Clean generated files"
    cmds:
      - find terraform -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
      - find terraform -name "*.tfplan" -delete 2>/dev/null || true
      - find terraform -name ".terraform.lock.hcl" -delete 2>/dev/null || true
      - rm -rf .task/

  # ============================================================================
  # ENVIRONMENT VALIDATION
  # ============================================================================
  validate:env:
    desc: "Validate devcontainer environment (tools, auth, MCP)"
    cmds:
      - bash .devcontainer/scripts/validate.sh

  validate:env:json:
    desc: "Validate environment (JSON output)"
    cmds:
      - bash .devcontainer/scripts/validate.sh --json

  validate:env:quiet:
    desc: "Validate environment (quiet mode)"
    cmds:
      - bash .devcontainer/scripts/validate.sh --quiet
EOF
}

# ==============================================================================
# Services Repo DevContainer
# ==============================================================================

generate_services_devcontainer() {
  local output_dir=$1
  log_info "Generating services-repo devcontainer in $output_dir"

  mkdir -p "$output_dir/.devcontainer/scripts"

  # devcontainer.json
  cat > "$output_dir/.devcontainer/devcontainer.json" << 'EOF'
{
  "name": "services-dev",
  "dockerComposeFile": ["docker-compose.yml"],
  "service": "services-dev",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "golang.go",
        "vscjava.vscode-java-pack",
        "ms-python.python",
        "redhat.vscode-yaml",
        "humao.rest-client",
        "ms-vscode-remote.remote-containers",
        "esbenp.prettier-vscode",
        "mermaidchart.vscode-mermaid-chart",
        "bierner.markdown-mermaid"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash",
        "go.useLanguageServer": true,
        "go.lintTool": "golangci-lint",
        "python.defaultInterpreterPath": "/usr/bin/python3",
        "java.configuration.runtimes": [
          {
            "name": "JavaSE-21",
            "path": "/usr/lib/jvm/java-21-openjdk"
          }
        ]
      },
      "mcp": {
        "servers": {
          "harness": {
            "command": "npx",
            "args": ["-y", "harness-mcp-v2"],
            "env": {
              "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
              "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
              "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
              "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
              "HARNESS_TOOLSETS": "${containerEnv:HARNESS_TOOLSETS}"
            }
          },
          "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {
              "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}"
            }
          },
          "perplexity": {
            "command": "npx",
            "args": ["-y", "@perplexity-ai/mcp-server"],
            "env": {
              "PERPLEXITY_API_KEY": "${containerEnv:PERPLEXITY_API_KEY}"
            }
          }
        }
      }
    }
  },
  "remoteEnv": {
    "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
    "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
    "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
    "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
    "HARNESS_TOOLSETS": "${containerEnv:HARNESS_TOOLSETS}",
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}",
    "GH_TOKEN": "${containerEnv:GH_TOKEN}",
    "PERPLEXITY_API_KEY": "${containerEnv:PERPLEXITY_API_KEY}",
    "SHIFTLEFT_ACCESS_TOKEN": "${containerEnv:SHIFTLEFT_ACCESS_TOKEN}",
    "SHIFTLEFT_ORG_ID": "${containerEnv:SHIFTLEFT_ORG_ID}",
    "GIT_USER_NAME": "${containerEnv:GIT_USER_NAME}",
    "GIT_USER_EMAIL": "${containerEnv:GIT_USER_EMAIL}"
  },
  "remoteUser": "devuser",
  "postCreateCommand": "bash .devcontainer/scripts/post-create.sh",
  "postStartCommand": "bash .devcontainer/scripts/post-start.sh"
}
EOF

  # docker-compose.yml
  cat > "$output_dir/.devcontainer/docker-compose.yml" << 'EOF'
version: "3.8"

services:
  services-dev:
    build:
      context: .
      dockerfile: Dockerfile
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    env_file:
      - .env
    volumes:
      - ../:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
      - ${HOME}/.config/gcloud:/home/devuser/.config/gcloud:ro
      - ${HOME}/.kube:/home/devuser/.kube:ro
    working_dir: /workspace
    user: devuser
    container_name: services-dev
    command: /bin/bash -c "while sleep 1000; do :; done"
EOF

  # Dockerfile
  cat > "$output_dir/.devcontainer/Dockerfile" << 'EOF'
# =============================================================================
# services-repo DevContainer
# Multi-language: Go, Java, Python
# =============================================================================
FROM alpine:3.19

USER root

# -----------------------------------------------------------------------------
# Architecture detection (works for amd64 and arm64)
# -----------------------------------------------------------------------------
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}

# -----------------------------------------------------------------------------
# Base dependencies + Go
# -----------------------------------------------------------------------------
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    git curl wget bash jq yq unzip \
    build-base make \
    docker-cli docker-cli-compose \
    nodejs npm \
    python3 py3-pip \
    openjdk21 maven \
    go \
    ca-certificates sudo shadow \
    github-cli

# -----------------------------------------------------------------------------
# Gradle
# -----------------------------------------------------------------------------
ARG GRADLE_VERSION=8.5
RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
      -O /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt && \
    ln -s /opt/gradle-${GRADLE_VERSION}/bin/gradle /usr/local/bin/gradle && \
    rm /tmp/gradle.zip

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${PATH}:${JAVA_HOME}/bin"

# -----------------------------------------------------------------------------
# Non-root user
# -----------------------------------------------------------------------------
RUN adduser -D -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Go paths
RUN mkdir -p /home/devuser/go/pkg/mod /home/devuser/go/bin && \
    chown -R devuser:devuser /home/devuser/go

ENV GOPATH=/home/devuser/go
ENV GOMODCACHE=/home/devuser/go/pkg/mod
ENV PATH="${PATH}:/home/devuser/go/bin:/usr/lib/go/bin"

# -----------------------------------------------------------------------------
# Go tools (pinned versions compatible with Go 1.21)
# -----------------------------------------------------------------------------
ENV GOBIN=/usr/local/bin
RUN go install golang.org/x/tools/gopls@v0.15.3 || true && \
    go install github.com/go-delve/delve/cmd/dlv@v1.22.1 || true && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.57.2 || true && \
    go install github.com/jstemmer/go-junit-report/v2@v2.1.0 || true && \
    rm -rf /root/.cache/go-build /root/go

# -----------------------------------------------------------------------------
# Taskfile (task runner)
# -----------------------------------------------------------------------------
ARG TASK_VERSION=v3.35.1
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin task && \
    chmod +x /usr/local/bin/task

# -----------------------------------------------------------------------------
# CLI tools via npm
# -----------------------------------------------------------------------------
RUN npm install -g \
    @anthropic-ai/claude-code \
    harness-mcp-v2 \
    @modelcontextprotocol/server-github \
    @perplexity-ai/mcp-server \
    @stoplight/spectral-cli

# -----------------------------------------------------------------------------
# Workspace
# -----------------------------------------------------------------------------
RUN mkdir -p /workspace && chown -R devuser:devuser /workspace

USER devuser
WORKDIR /workspace

CMD ["bash"]
EOF

  # Generate Taskfile
  generate_services_taskfile "$output_dir"

  # Generate validation script
  generate_services_validation_script "$output_dir"

  # Generate common files
  generate_env_template "$output_dir" "services"
  generate_post_create_script "$output_dir" "services"
  generate_post_start_script "$output_dir" "services"
  generate_gitignore_entry "$output_dir"

  log_success "services-repo devcontainer created at $output_dir/.devcontainer/"
}

# ==============================================================================
# Platform Repo DevContainer
# ==============================================================================

generate_platform_devcontainer() {
  local output_dir=$1
  log_info "Generating platform-repo devcontainer in $output_dir"

  mkdir -p "$output_dir/.devcontainer/scripts"

  # devcontainer.json
  cat > "$output_dir/.devcontainer/devcontainer.json" << 'EOF'
{
  "name": "platform-dev",
  "dockerComposeFile": ["docker-compose.yml"],
  "service": "platform-dev",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "redhat.vscode-yaml",
        "ms-azuretools.vscode-docker",
        "timonwong.shellcheck",
        "foxundermoon.shell-format",
        "humao.rest-client",
        "ms-vscode-remote.remote-containers",
        "mermaidchart.vscode-mermaid-chart",
        "bierner.markdown-mermaid",
        "esbenp.prettier-vscode"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash",
        "yaml.schemas": {
          "https://json.schemastore.org/github-workflow.json": ".github/workflows/*.yaml",
          "https://raw.githubusercontent.com/harness/harness-schema/main/v0/pipeline.json": ".harness/**/*.yaml"
        },
        "shellcheck.enable": true,
        "shellcheck.executablePath": "/usr/bin/shellcheck"
      },
      "mcp": {
        "servers": {
          "harness": {
            "command": "npx",
            "args": ["-y", "harness-mcp-v2"],
            "env": {
              "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
              "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
              "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
              "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
              "HARNESS_TOOLSETS": "pipelines,templates,policies,triggers,connectors"
            }
          },
          "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {
              "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}"
            }
          }
        }
      }
    }
  },
  "remoteEnv": {
    "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
    "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
    "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
    "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
    "HARNESS_TOOLSETS": "${containerEnv:HARNESS_TOOLSETS}",
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}",
    "GH_TOKEN": "${containerEnv:GH_TOKEN}",
    "GIT_USER_NAME": "${containerEnv:GIT_USER_NAME}",
    "GIT_USER_EMAIL": "${containerEnv:GIT_USER_EMAIL}"
  },
  "remoteUser": "devuser",
  "postCreateCommand": "bash .devcontainer/scripts/post-create.sh",
  "postStartCommand": "bash .devcontainer/scripts/post-start.sh"
}
EOF

  # docker-compose.yml
  cat > "$output_dir/.devcontainer/docker-compose.yml" << 'EOF'
version: "3.8"

services:
  platform-dev:
    build:
      context: .
      dockerfile: Dockerfile
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    env_file:
      - .env
    volumes:
      - ../:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    working_dir: /workspace
    user: devuser
    container_name: platform-dev
    command: /bin/bash -c "while sleep 1000; do :; done"
EOF

  # Dockerfile
  cat > "$output_dir/.devcontainer/Dockerfile" << 'EOF'
# =============================================================================
# platform-repo DevContainer
# CI/CD, Docker, YAML, Security tooling
# =============================================================================
FROM alpine:3.19

USER root

# -----------------------------------------------------------------------------
# Architecture detection (works for amd64 and arm64)
# -----------------------------------------------------------------------------
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}

# -----------------------------------------------------------------------------
# Base dependencies
# -----------------------------------------------------------------------------
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    git curl wget bash jq yq \
    make shellcheck \
    docker-cli docker-cli-compose docker-cli-buildx \
    nodejs npm \
    python3 py3-pip \
    ca-certificates sudo shadow \
    github-cli

# -----------------------------------------------------------------------------
# OPA (Open Policy Agent)
# -----------------------------------------------------------------------------
ARG OPA_VERSION=v0.60.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -L -o /usr/local/bin/opa \
    "https://openpolicyagent.org/downloads/${OPA_VERSION}/opa_linux_${ARCH}_static" && \
    chmod +x /usr/local/bin/opa

# -----------------------------------------------------------------------------
# Taskfile (task runner)
# -----------------------------------------------------------------------------
ARG TASK_VERSION=v3.35.1
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin task && \
    chmod +x /usr/local/bin/task

# -----------------------------------------------------------------------------
# Non-root user
# -----------------------------------------------------------------------------
RUN adduser -D -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# -----------------------------------------------------------------------------
# CLI tools via npm
# -----------------------------------------------------------------------------
RUN npm install -g \
    @anthropic-ai/claude-code \
    harness-mcp-v2 \
    @modelcontextprotocol/server-github \
    @stoplight/spectral-cli \
    ajv-cli

# -----------------------------------------------------------------------------
# Python tools
# -----------------------------------------------------------------------------
RUN pip3 install --break-system-packages \
    yamllint \
    yq

# -----------------------------------------------------------------------------
# Workspace
# -----------------------------------------------------------------------------
RUN mkdir -p /workspace && chown -R devuser:devuser /workspace

USER devuser
WORKDIR /workspace

CMD ["bash"]
EOF

  # Generate Taskfile
  generate_platform_taskfile "$output_dir"

  # Generate validation script
  generate_platform_validation_script "$output_dir"

  # Generate common files
  generate_env_template "$output_dir" "platform"
  generate_post_create_script "$output_dir" "platform"
  generate_post_start_script "$output_dir" "platform"
  generate_gitignore_entry "$output_dir"

  log_success "platform-repo devcontainer created at $output_dir/.devcontainer/"
}

# ==============================================================================
# Infra Repo DevContainer
# ==============================================================================

generate_infra_devcontainer() {
  local output_dir=$1
  log_info "Generating infra-repo devcontainer in $output_dir"

  mkdir -p "$output_dir/.devcontainer/scripts"

  # devcontainer.json
  cat > "$output_dir/.devcontainer/devcontainer.json" << 'EOF'
{
  "name": "infra-dev",
  "dockerComposeFile": ["docker-compose.yml"],
  "service": "infra-dev",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "hashicorp.terraform",
        "ms-kubernetes-tools.vscode-kubernetes-tools",
        "redhat.vscode-yaml",
        "tim-koehler.helm-intellisense",
        "ms-azuretools.vscode-docker",
        "mermaidchart.vscode-mermaid-chart",
        "bierner.markdown-mermaid",
        "humao.rest-client"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash",
        "terraform.languageServer.enable": true,
        "terraform.experimentalFeatures.validateOnSave": true,
        "vs-kubernetes": {
          "vs-kubernetes.kubectl-path": "/usr/local/bin/kubectl",
          "vs-kubernetes.helm-path": "/usr/local/bin/helm"
        }
      },
      "mcp": {
        "servers": {
          "harness": {
            "command": "npx",
            "args": ["-y", "harness-mcp-v2"],
            "env": {
              "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
              "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
              "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
              "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}"
            }
          },
          "kubernetes": {
            "command": "npx",
            "args": ["-y", "mcp-server-kubernetes"],
            "env": {
              "KUBECONFIG": "${containerEnv:KUBECONFIG}"
            }
          },
          "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {
              "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}"
            }
          }
        }
      }
    }
  },
  "remoteEnv": {
    "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
    "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
    "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
    "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}",
    "GH_TOKEN": "${containerEnv:GH_TOKEN}",
    "KUBECONFIG": "${containerEnv:KUBECONFIG}",
    "GOOGLE_CLOUD_PROJECT": "${containerEnv:GOOGLE_CLOUD_PROJECT}",
    "GOOGLE_APPLICATION_CREDENTIALS": "${containerEnv:GOOGLE_APPLICATION_CREDENTIALS}",
    "GIT_USER_NAME": "${containerEnv:GIT_USER_NAME}",
    "GIT_USER_EMAIL": "${containerEnv:GIT_USER_EMAIL}"
  },
  "remoteUser": "devuser",
  "postCreateCommand": "bash .devcontainer/scripts/post-create.sh",
  "postStartCommand": "bash .devcontainer/scripts/post-start.sh"
}
EOF

  # docker-compose.yml
  cat > "$output_dir/.devcontainer/docker-compose.yml" << 'EOF'
version: "3.8"

services:
  infra-dev:
    build:
      context: .
      dockerfile: Dockerfile
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    env_file:
      - .env
    volumes:
      - ../:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
      - ${HOME}/.config/gcloud:/home/devuser/.config/gcloud:ro
      - ${HOME}/.kube:/home/devuser/.kube:ro
      - ${HOME}/.aws:/home/devuser/.aws:ro
    working_dir: /workspace
    user: devuser
    container_name: infra-dev
    command: /bin/bash -c "while sleep 1000; do :; done"
EOF

  # Dockerfile
  cat > "$output_dir/.devcontainer/Dockerfile" << 'EOF'
# =============================================================================
# infra-repo DevContainer
# Terraform, Kubernetes, Helm, Cloud CLIs
# =============================================================================
FROM alpine:3.19

USER root

# -----------------------------------------------------------------------------
# Architecture detection (works for amd64 and arm64)
# -----------------------------------------------------------------------------
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}

# -----------------------------------------------------------------------------
# Base dependencies
# -----------------------------------------------------------------------------
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    git curl wget bash jq yq unzip \
    make \
    docker-cli docker-cli-compose \
    nodejs npm \
    python3 py3-pip \
    ca-certificates sudo shadow \
    github-cli \
    openssh-client

# -----------------------------------------------------------------------------
# tfenv + Terraform
# -----------------------------------------------------------------------------
RUN git clone --depth=1 https://github.com/tfutils/tfenv.git /opt/tfenv && \
    ln -s /opt/tfenv/bin/* /usr/local/bin && \
    tfenv install latest && \
    tfenv use latest

# -----------------------------------------------------------------------------
# tflint (pre-built binary)
# -----------------------------------------------------------------------------
ARG TFLINT_VERSION=v0.50.3
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_${ARCH}.zip" \
    -o /tmp/tflint.zip && \
    unzip -q /tmp/tflint.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/tflint && \
    rm /tmp/tflint.zip

# -----------------------------------------------------------------------------
# terraform-docs (pre-built binary)
# -----------------------------------------------------------------------------
ARG TERRAFORM_DOCS_VERSION=v0.18.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin terraform-docs && \
    chmod +x /usr/local/bin/terraform-docs

# -----------------------------------------------------------------------------
# kubectl
# -----------------------------------------------------------------------------
ARG KUBECTL_VERSION=v1.30.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# -----------------------------------------------------------------------------
# Helm
# -----------------------------------------------------------------------------
ARG HELM_VERSION=v3.14.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" | \
    tar xz -C /tmp && \
    mv /tmp/linux-${ARCH}/helm /usr/local/bin/helm && \
    rm -rf /tmp/linux-${ARCH}

# -----------------------------------------------------------------------------
# Kustomize
# -----------------------------------------------------------------------------
ARG KUSTOMIZE_VERSION=v5.3.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin

# -----------------------------------------------------------------------------
# Google Cloud SDK
# -----------------------------------------------------------------------------
RUN curl -sSL https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz \
    -o /tmp/google-cloud-sdk.tar.gz && \
    mkdir -p /usr/local/gcloud && \
    tar -C /usr/local/gcloud -xzf /tmp/google-cloud-sdk.tar.gz && \
    /usr/local/gcloud/google-cloud-sdk/install.sh --quiet && \
    rm /tmp/google-cloud-sdk.tar.gz

ENV PATH="${PATH}:/usr/local/gcloud/google-cloud-sdk/bin"

RUN gcloud components install gke-gcloud-auth-plugin --quiet || true

# -----------------------------------------------------------------------------
# OPA (Open Policy Agent)
# -----------------------------------------------------------------------------
ARG OPA_VERSION=v0.60.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -L -o /usr/local/bin/opa \
    "https://openpolicyagent.org/downloads/${OPA_VERSION}/opa_linux_${ARCH}_static" && \
    chmod +x /usr/local/bin/opa

# -----------------------------------------------------------------------------
# Taskfile (task runner)
# -----------------------------------------------------------------------------
ARG TASK_VERSION=v3.35.1
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin task && \
    chmod +x /usr/local/bin/task

# -----------------------------------------------------------------------------
# Non-root user
# -----------------------------------------------------------------------------
RUN adduser -D -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# -----------------------------------------------------------------------------
# CLI tools via npm
# -----------------------------------------------------------------------------
RUN npm install -g \
    @anthropic-ai/claude-code \
    harness-mcp-v2 \
    @modelcontextprotocol/server-github \
    mcp-server-kubernetes

# -----------------------------------------------------------------------------
# Workspace
# -----------------------------------------------------------------------------
RUN mkdir -p /workspace && chown -R devuser:devuser /workspace

USER devuser
WORKDIR /workspace

CMD ["bash"]
EOF

  # Generate Taskfile
  generate_infra_taskfile "$output_dir"

  # Generate validation script
  generate_infra_validation_script "$output_dir"

  # Generate common files
  generate_env_template "$output_dir" "infra"
  generate_post_create_script "$output_dir" "infra"
  generate_post_start_script "$output_dir" "infra"
  generate_gitignore_entry "$output_dir"

  log_success "infra-repo devcontainer created at $output_dir/.devcontainer/"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
  if [ $# -lt 2 ]; then
    usage
  fi

  local repo_type=$1
  local output_dir=$2

  log_info "DevContainer Scaffolding Script"
  log_info "================================"

  case $repo_type in
    services)
      generate_services_devcontainer "$output_dir"
      ;;
    platform)
      generate_platform_devcontainer "$output_dir"
      ;;
    infra)
      generate_infra_devcontainer "$output_dir"
      ;;
    all)
      log_info "Generating all devcontainers..."
      mkdir -p "$output_dir/services-repo"
      mkdir -p "$output_dir/platform-repo"
      mkdir -p "$output_dir/infra-repo"
      generate_services_devcontainer "$output_dir/services-repo"
      generate_platform_devcontainer "$output_dir/platform-repo"
      generate_infra_devcontainer "$output_dir/infra-repo"
      log_success "All devcontainers generated in $output_dir/"
      ;;
    *)
      log_error "Unknown repo type: $repo_type"
      usage
      ;;
  esac

  echo ""
  log_info "Next steps:"
  echo "  1. Copy .env.template to .env and fill in your values"
  echo "  2. Open the folder in VS Code"
  echo "  3. Click 'Reopen in Container' when prompted"
  echo ""
}

main "$@"
