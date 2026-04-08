#!/bin/sh
set -e

echo "[post-start] configuring Docker socket permissions..."
if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  if ! getent group docker >/dev/null 2>&1; then
    sudo addgroup -g "$DOCKER_GID" docker 2>/dev/null || true
  fi
  sudo addgroup devuser docker 2>/dev/null || true
  sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

echo "[post-start] validating devtoolchain..."

for cmd in claude harness-mcp-v2 gh gcloud kubectl terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "WARN: $cmd not found in PATH"
  fi
done

[ -n "$HARNESS_API_KEY" ] || echo "WARN: HARNESS_API_KEY is empty"
[ -n "$HARNESS_DEFAULT_ORG_ID" ] || echo "WARN: HARNESS_DEFAULT_ORG_ID is empty"
[ -n "$HARNESS_DEFAULT_PROJECT_ID" ] || echo "WARN: HARNESS_DEFAULT_PROJECT_ID is empty"
[ -n "$HARNESS_BASE_URL" ] || echo "WARN: HARNESS_BASE_URL is empty"

[ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ] || echo "WARN: GITHUB_PERSONAL_ACCESS_TOKEN is empty"
[ -n "$GH_TOKEN" ] || echo "WARN: GH_TOKEN is empty"

echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"devcontainer-check","version":"1.0.0"},"capabilities":{}}}' \
  | harness-mcp-v2 >/dev/null 2>&1 || echo "WARN: harness-mcp-v2 initialize failed"

echo "[post-start] done"
