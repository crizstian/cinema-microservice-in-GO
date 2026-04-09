#!/bin/sh
set -e

echo "[post-create] bootstrap inicial..."

git config --global user.name "Cristian Ramirez" || true
git config --global user.email "cristiano.rosetti@gmail.com" || true

# Install ShiftLeft CLI (sl) if not present
if ! command -v sl > /dev/null 2>&1; then
  echo "[post-create] Installing ShiftLeft CLI..."
  curl https://cdn.shiftleft.io/download/sl > /tmp/sl
  chmod +x /tmp/sl
  sudo mv /tmp/sl /usr/local/bin/sl
  echo "[post-create] ShiftLeft CLI installed"
fi

# Authenticate ShiftLeft if token is available
if [ -n "$SHIFTLEFT_ACCESS_TOKEN" ] && [ -n "$SHIFTLEFT_ORG_ID" ]; then
  echo "[post-create] Authenticating ShiftLeft..."
  sl auth --token "$SHIFTLEFT_ACCESS_TOKEN" --org "$SHIFTLEFT_ORG_ID" || true
fi

echo "[post-create] listo"
