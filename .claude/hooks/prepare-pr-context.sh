#!/bin/sh
set -e
git status --short || true
git diff --stat || true
gh pr status || true
