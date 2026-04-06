#!/bin/sh
set -e

echo "[post-create] bootstrap inicial..."

git config --global user.name "Cristian Ramirez" || true
git config --global user.email "cristiano.rosetti@gmail.com" || true

echo "[post-create] listo"
