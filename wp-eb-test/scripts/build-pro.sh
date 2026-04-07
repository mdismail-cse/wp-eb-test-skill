#!/bin/bash
set -e

PRO_DIR="${1:-.}"

echo "Building Essential Blocks Pro..."

cd "$PRO_DIR"

# Pull submodules if any
if [ -f ".gitmodules" ]; then
  echo "Initializing submodules..."
  git submodule update --init --recursive
fi

echo "Installing dependencies..."
pnpm install --frozen-lockfile 2>/dev/null || pnpm install

echo "Building pro plugin..."
pnpm run build

echo "Pro plugin build complete."
