#!/bin/bash
# =============================================================================
# Demo Lab System - Repeatable CI/CD Scenarios
# =============================================================================
# Usage:
#   ./demo-lab.sh setup <scenario>    - Setup scenario
#   ./demo-lab.sh run <scenario>      - Execute demo
#   ./demo-lab.sh validate <scenario> - Validate results
#   ./demo-lab.sh reset <scenario>    - Reset scenario
#   ./demo-lab.sh list                - List available scenarios
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCENARIOS_DIR="$REPO_ROOT/docs/demo-blocks/CI/scenarios"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Scenario Definitions
# =============================================================================

declare -A SCENARIOS
SCENARIOS=(
    ["01-basic-ci"]="Basic CI Pipeline - Single service, format, lint, test"
    ["02-monorepo-looping"]="Monorepo Looping Strategy - Multiple services in parallel"
    ["03-security-gates"]="Shift-Left Security - SAST/SCA blocking vulnerabilities"
    ["04-ai-devops-mcp"]="AI-Assisted DevOps - MCP + Claude integration"
    ["05-full-pipeline"]="Full Pipeline - Build, release, semantic versioning"
)

# =============================================================================
# Command: list
# =============================================================================

cmd_list() {
    echo ""
    echo "Available Demo Scenarios:"
    echo "========================="
    echo ""
    for scenario in "${!SCENARIOS[@]}"; do
        echo "  $scenario"
        echo "    ${SCENARIOS[$scenario]}"
        echo ""
    done | sort
}

# =============================================================================
# Command: setup
# =============================================================================

cmd_setup() {
    local scenario=$1

    if [ -z "$scenario" ]; then
        log_error "Usage: demo-lab.sh setup <scenario>"
        cmd_list
        exit 1
    fi

    if [ -z "${SCENARIOS[$scenario]}" ]; then
        log_error "Unknown scenario: $scenario"
        cmd_list
        exit 1
    fi

    log_info "Setting up scenario: $scenario"

    # Ensure we're on clean state
    git stash --include-untracked 2>/dev/null || true

    # Create demo branch
    local branch_name="demo/scenario-$scenario"
    local base_branch="step-1"

    # Delete existing branch if exists
    git branch -D "$branch_name" 2>/dev/null || true
    git push origin --delete "$branch_name" 2>/dev/null || true

    # Create fresh branch
    git checkout "$base_branch"
    git pull origin "$base_branch" 2>/dev/null || true
    git checkout -b "$branch_name"

    # Apply scenario-specific changes
    case $scenario in
        "01-basic-ci")
            setup_scenario_01
            ;;
        "02-monorepo-looping")
            setup_scenario_02
            ;;
        "03-security-gates")
            setup_scenario_03
            ;;
        "04-ai-devops-mcp")
            setup_scenario_04
            ;;
        "05-full-pipeline")
            setup_scenario_05
            ;;
    esac

    log_success "Scenario $scenario setup complete"
    log_info "Branch: $branch_name"
    log_info "Run 'task demo:run SCENARIO=$scenario' to execute"
}

setup_scenario_01() {
    log_info "Applying changes for basic-ci scenario..."

    # Modify movie service
    local file="services/movie/internal/api/handlers.go"
    if [ -f "$file" ]; then
        # Add a small change (comment update)
        sed -i.bak 's|// Handler|// Handler - Cinema Movie API Handler|g' "$file" 2>/dev/null || \
        sed -i '' 's|// Handler|// Handler - Cinema Movie API Handler|g' "$file"
        rm -f "${file}.bak"
    fi

    # Stage changes
    git add -A
    git commit -m "docs(movie): update handler documentation

This commit triggers the CI pipeline for demo purposes.

Signed-off-by: Demo User <demo@example.com>"

    log_success "Changes applied to movie service"
}

setup_scenario_02() {
    log_info "Applying changes for monorepo-looping scenario..."

    # Modify multiple services
    for service in movie booking payment; do
        local file="services/$service/internal/api/handlers.go"
        if [ -f "$file" ]; then
            sed -i.bak "s|// Handler|// Handler - Cinema $service API Handler|g" "$file" 2>/dev/null || \
            sed -i '' "s|// Handler|// Handler - Cinema $service API Handler|g" "$file"
            rm -f "${file}.bak"
        fi
    done

    git add -A
    git commit -m "docs(movie,booking,payment): update handler documentation

This commit modifies 3 services to demonstrate parallel execution.

Signed-off-by: Demo User <demo@example.com>"

    log_success "Changes applied to movie, booking, payment services"
}

setup_scenario_03() {
    log_info "Applying changes for security-gates scenario..."

    # Create a file with intentional security issue (for demo only)
    cat >> services/payment/internal/api/demo_vuln.go << 'EOF'
package api

// DEMO FILE - Intentional vulnerability for security demo
// This file should be removed after demo

import (
    "database/sql"
    "fmt"
    "net/http"
)

// DemoVulnHandler - DO NOT USE IN PRODUCTION
// This demonstrates SQL injection vulnerability detection
func DemoVulnHandler(db *sql.DB) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        userID := r.URL.Query().Get("user_id")
        // VULNERABLE: SQL Injection - SAST should detect this
        query := fmt.Sprintf("SELECT * FROM users WHERE id = '%s'", userID)
        _, _ = db.Query(query)
    }
}
EOF

    git add -A
    git commit -m "feat(payment): add demo handler (SECURITY TEST)

This commit intentionally introduces a vulnerability for demo.
SAST should detect and block this PR.

Signed-off-by: Demo User <demo@example.com>"

    log_success "Security vulnerability added for demo"
    log_warning "Remember to run 'demo:fix' to show remediation"
}

setup_scenario_04() {
    log_info "Setting up AI-DevOps MCP scenario..."

    # This scenario is interactive - just prepare the environment
    echo "# AI-DevOps MCP Demo" > /tmp/mcp-demo-ready.txt

    log_success "MCP scenario ready"
    log_info "Open VS Code and use Claude Code for interactive demo"
    log_info "See: docs/demo-blocks/CI/HARNESS_SE_DEMO_PLAYBOOK.md"
}

setup_scenario_05() {
    log_info "Applying changes for full-pipeline scenario..."

    # Add a new feature to movie service
    cat >> services/movie/internal/api/recommendations.go << 'EOF'
package api

import (
    "encoding/json"
    "net/http"
)

// Recommendation represents a movie recommendation
type Recommendation struct {
    MovieID     string  `json:"movie_id"`
    Title       string  `json:"title"`
    Score       float64 `json:"score"`
    Reason      string  `json:"reason"`
}

// GetRecommendations returns movie recommendations for a user
func (h *Handler) GetRecommendations(w http.ResponseWriter, r *http.Request) {
    // Demo implementation
    recommendations := []Recommendation{
        {MovieID: "mov_001", Title: "Inception", Score: 0.95, Reason: "Based on your history"},
        {MovieID: "mov_002", Title: "Interstellar", Score: 0.92, Reason: "Similar genre"},
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(recommendations)
}
EOF

    git add -A
    git commit -m "feat(movie): add recommendations endpoint

This commit adds a new endpoint for movie recommendations.
Should trigger MINOR version bump (feat).

Signed-off-by: Demo User <demo@example.com>"

    log_success "New feature added to movie service"
}

# =============================================================================
# Command: run
# =============================================================================

cmd_run() {
    local scenario=$1
    local merged=${2:-false}

    if [ -z "$scenario" ]; then
        log_error "Usage: demo-lab.sh run <scenario> [--merged]"
        exit 1
    fi

    local branch_name="demo/scenario-$scenario"

    log_info "Executing demo scenario: $scenario"

    # Verify we're on the correct branch
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "$branch_name" ]; then
        git checkout "$branch_name"
    fi

    # Push branch
    log_info "Pushing branch to origin..."
    git push -u origin "$branch_name" --force

    # Create PR
    log_info "Creating Pull Request..."

    local pr_title
    case $scenario in
        "01-basic-ci")
            pr_title="[DEMO] Basic CI Pipeline - Movie Service"
            ;;
        "02-monorepo-looping")
            pr_title="[DEMO] Monorepo Looping - Multiple Services"
            ;;
        "03-security-gates")
            pr_title="[DEMO] Security Gates - Vulnerability Detection"
            ;;
        "05-full-pipeline")
            pr_title="feat(movie): add recommendations endpoint"
            ;;
        *)
            pr_title="[DEMO] Scenario $scenario"
            ;;
    esac

    # Check if PR already exists
    existing_pr=$(gh pr list --head "$branch_name" --json number --jq '.[0].number' 2>/dev/null || echo "")

    if [ -n "$existing_pr" ]; then
        log_info "PR #$existing_pr already exists"
        pr_url=$(gh pr view "$existing_pr" --json url --jq '.url')
    else
        pr_url=$(gh pr create \
            --title "$pr_title" \
            --body "## Demo Scenario: $scenario

${SCENARIOS[$scenario]}

---
*Auto-generated by demo-lab system*" \
            --base step-1 \
            --head "$branch_name" 2>&1)
    fi

    log_success "PR created/found: $pr_url"
    log_info "Pipeline should trigger automatically"
    log_info "Open Harness UI to observe execution"

    # If merged flag, simulate merge (for scenario 05)
    if [ "$merged" == "--merged" ] || [ "$merged" == "true" ]; then
        log_warning "Merge simulation requested"
        log_info "In real demo, merge the PR manually in Harness Code"
    fi
}

# =============================================================================
# Command: validate
# =============================================================================

cmd_validate() {
    local scenario=$1

    if [ -z "$scenario" ]; then
        log_error "Usage: demo-lab.sh validate <scenario>"
        exit 1
    fi

    log_info "Validating scenario: $scenario"

    # Get latest execution
    local branch_name="demo/scenario-$scenario"

    # Check PR status
    pr_number=$(gh pr list --head "$branch_name" --json number --jq '.[0].number' 2>/dev/null || echo "")

    if [ -z "$pr_number" ]; then
        log_error "No PR found for branch $branch_name"
        exit 1
    fi

    log_info "Checking PR #$pr_number..."

    # Get PR checks status
    checks_status=$(gh pr checks "$pr_number" 2>&1 || echo "pending")

    echo ""
    echo "PR Checks Status:"
    echo "================="
    echo "$checks_status"
    echo ""

    # Validate based on scenario
    case $scenario in
        "01-basic-ci")
            if echo "$checks_status" | grep -q "pass"; then
                log_success "Scenario 01 validation PASSED"
            else
                log_warning "Scenario 01 validation - checks still running or failed"
            fi
            ;;
        "03-security-gates")
            if echo "$checks_status" | grep -q "fail"; then
                log_success "Scenario 03 validation PASSED - Security scan correctly blocked PR"
            else
                log_warning "Scenario 03 - Expected failure, check SAST/SCA configuration"
            fi
            ;;
        *)
            log_info "Check Harness UI for detailed validation"
            ;;
    esac
}

# =============================================================================
# Command: reset
# =============================================================================

cmd_reset() {
    local scenario=$1

    if [ -z "$scenario" ]; then
        # Reset all
        log_info "Resetting all demo scenarios..."

        git checkout step-1

        for s in "${!SCENARIOS[@]}"; do
            local branch_name="demo/scenario-$s"
            git branch -D "$branch_name" 2>/dev/null || true
            git push origin --delete "$branch_name" 2>/dev/null || true
        done

        log_success "All scenarios reset"
    else
        local branch_name="demo/scenario-$scenario"

        log_info "Resetting scenario: $scenario"

        # Close PR if exists
        pr_number=$(gh pr list --head "$branch_name" --json number --jq '.[0].number' 2>/dev/null || echo "")
        if [ -n "$pr_number" ]; then
            gh pr close "$pr_number" 2>/dev/null || true
        fi

        # Delete branch
        git checkout step-1
        git branch -D "$branch_name" 2>/dev/null || true
        git push origin --delete "$branch_name" 2>/dev/null || true

        log_success "Scenario $scenario reset"
    fi
}

# =============================================================================
# Command: fix (for security scenario)
# =============================================================================

cmd_fix() {
    local scenario=$1

    if [ "$scenario" != "03-security-gates" ]; then
        log_error "Fix command only applies to scenario 03-security-gates"
        exit 1
    fi

    log_info "Applying security fix..."

    # Remove the vulnerable file
    rm -f services/payment/internal/api/demo_vuln.go

    git add -A
    git commit -m "fix(payment): remove vulnerable code

Removed SQL injection vulnerability detected by SAST.
This demonstrates the fix → re-run → pass workflow.

Signed-off-by: Demo User <demo@example.com>"

    git push origin "demo/scenario-$scenario"

    log_success "Security fix applied and pushed"
    log_info "Pipeline will re-run automatically"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local command=${1:-list}
    shift || true

    case $command in
        list)
            cmd_list
            ;;
        setup)
            cmd_setup "$@"
            ;;
        run)
            cmd_run "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        reset)
            cmd_reset "$@"
            ;;
        fix)
            cmd_fix "$@"
            ;;
        *)
            echo "Usage: demo-lab.sh <command> [options]"
            echo ""
            echo "Commands:"
            echo "  list              - List available scenarios"
            echo "  setup <scenario>  - Setup a demo scenario"
            echo "  run <scenario>    - Execute the demo"
            echo "  validate <scenario> - Validate results"
            echo "  reset [scenario]  - Reset scenario (or all)"
            echo "  fix <scenario>    - Apply fix (security scenario)"
            exit 1
            ;;
    esac
}

main "$@"
