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
