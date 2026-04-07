#!/bin/bash
set -e

PLUGIN_DIR="${1:-.}"
CONTROLS_PATH="${2:-src/controls}"

echo "Building Controls submodule..."

cd "$PLUGIN_DIR/$CONTROLS_PATH"

echo "Installing dependencies..."
pnpm install --frozen-lockfile 2>/dev/null || pnpm install

echo "Building controls..."
pnpm run build

echo "Controls build complete."
