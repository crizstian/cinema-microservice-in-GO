#!/bin/bash
# Create git tag and optionally push for a service release
# Usage: ./release.sh <service> [bump_type] [--push]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICE="${1:?Usage: $0 <service> [patch|minor|major] [--push]}"
BUMP_TYPE="${2:-patch}"
PUSH_FLAG="${3:-}"

cd "$(git rev-parse --show-toplevel)"

CURRENT_VERSION=$("$SCRIPT_DIR/version.sh" "$SERVICE")
NEW_VERSION=$("$SCRIPT_DIR/version.sh" "$SERVICE" "$BUMP_TYPE")
TAG_NAME="${SERVICE}-v${NEW_VERSION}"
COMMIT_SHA=$(git rev-parse HEAD)

echo "=== Creating Git Tag for $SERVICE ==="
echo "Current version: v$CURRENT_VERSION"
echo "Bump type: $BUMP_TYPE"
echo "New version: v$NEW_VERSION"
echo "Tag name: $TAG_NAME"
echo "Commit: $COMMIT_SHA"
echo ""

if git tag -l "$TAG_NAME" | grep -q "$TAG_NAME"; then
  echo "ERROR: Tag $TAG_NAME already exists"
  exit 1
fi

git tag -a "$TAG_NAME" -m "Release $SERVICE v$NEW_VERSION"
echo "Created tag: $TAG_NAME"

if [ "$PUSH_FLAG" = "--push" ]; then
  echo "Pushing tag to origin..."
  git push origin "$TAG_NAME"
  echo "Pushed: $TAG_NAME"
fi

echo ""
echo "TAG_NAME=$TAG_NAME"
echo "NEW_VERSION=$NEW_VERSION"
