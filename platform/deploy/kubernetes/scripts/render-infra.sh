#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

COMPONENT="${1:-all}"

"${K8S_DIR}/bin/render" \
    -infra "$COMPONENT" \
    -base "$K8S_DIR"
