#!/bin/bash
set -e

PRO_DIR="${1:-.}"

echo "Building Essential Blocks Pro at $PRO_DIR..."

if [ -f "$PRO_DIR/.gitmodules" ]; then
  echo "Initializing submodules..."
  git -C "$PRO_DIR" submodule update --init --recursive
fi

echo "Installing dependencies..."
pnpm --dir "$PRO_DIR" install --frozen-lockfile 2>/dev/null || pnpm --dir "$PRO_DIR" install

echo "Building pro plugin..."
pnpm --dir "$PRO_DIR" run build

echo "Pro plugin build complete."
