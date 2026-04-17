#!/bin/bash
# Semantic versioning per service from git tags
# Usage: ./version.sh <service> [bump_type]
# Returns: current version, or calculates new version if bump_type provided

set -euo pipefail

SERVICE="${1:?Usage: $0 <service> [patch|minor|major]}"
BUMP_TYPE="${2:-}"

get_latest_version() {
  local svc="$1"
  local latest_tag

  latest_tag=$(git tag -l "${svc}-v*" 2>/dev/null | sort -V | tail -1 || echo "")

  if [ -z "$latest_tag" ]; then
    echo "0.0.0"
  else
    echo "${latest_tag#${svc}-v}"
  fi
}

calculate_new_version() {
  local current="$1"
  local bump="$2"

  local major minor patch
  major=$(echo "$current" | cut -d. -f1)
  minor=$(echo "$current" | cut -d. -f2)
  patch=$(echo "$current" | cut -d. -f3)

  case "$bump" in
    major)
      echo "$((major + 1)).0.0"
      ;;
    minor)
      echo "${major}.$((minor + 1)).0"
      ;;
    patch|*)
      echo "${major}.${minor}.$((patch + 1))"
      ;;
  esac
}

CURRENT_VERSION=$(get_latest_version "$SERVICE")

if [ -z "$BUMP_TYPE" ]; then
  echo "$CURRENT_VERSION"
else
  NEW_VERSION=$(calculate_new_version "$CURRENT_VERSION" "$BUMP_TYPE")
  echo "$NEW_VERSION"
fi
