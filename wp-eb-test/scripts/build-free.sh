#!/bin/bash
set -e

PLUGIN_DIR="${1:-.}"

echo "Building Essential Blocks (Free) at $PLUGIN_DIR..."

# Pull submodule if not initialized
if [ -f "$PLUGIN_DIR/.gitmodules" ]; then
  echo "Initializing submodules..."
  git -C "$PLUGIN_DIR" submodule update --init --recursive
fi

# Install and build controls first (dependency)
if [ -d "$PLUGIN_DIR/src/controls" ]; then
  echo "Building src/controls (dependency)..."
  pnpm --dir "$PLUGIN_DIR/src/controls" install --frozen-lockfile 2>/dev/null || pnpm --dir "$PLUGIN_DIR/src/controls" install
  pnpm --dir "$PLUGIN_DIR/src/controls" run build
fi

echo "Installing dependencies..."
pnpm --dir "$PLUGIN_DIR" install --frozen-lockfile 2>/dev/null || pnpm --dir "$PLUGIN_DIR" install

echo "Building free plugin..."
pnpm --dir "$PLUGIN_DIR" run build

echo "Free plugin build complete."
