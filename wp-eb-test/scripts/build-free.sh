#!/bin/bash
set -e

PLUGIN_DIR="${1:-.}"

echo "Building Essential Blocks (Free)..."

cd "$PLUGIN_DIR"

# Pull submodule if not initialized
if [ -f ".gitmodules" ]; then
  echo "Initializing submodules..."
  git submodule update --init --recursive
fi

# Install and build controls first (dependency)
if [ -d "src/controls" ]; then
  echo "Building src/controls (dependency)..."
  cd src/controls
  pnpm install --frozen-lockfile 2>/dev/null || pnpm install
  pnpm run build
  cd -
fi

# Install and build the free plugin
echo "Installing dependencies..."
pnpm install --frozen-lockfile 2>/dev/null || pnpm install

echo "Building free plugin..."
pnpm run build

echo "Free plugin build complete."
