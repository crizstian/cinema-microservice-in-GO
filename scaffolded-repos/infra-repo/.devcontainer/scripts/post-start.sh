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
