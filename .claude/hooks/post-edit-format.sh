#!/bin/sh
set -e
if command -v prettier >/dev/null 2>&1; then
  prettier --write . >/dev/null 2>&1 || true
fi
if command -v gofmt >/dev/null 2>&1; then
  find . -name "*.go" -type f -exec gofmt -w {} \; || true
fi
