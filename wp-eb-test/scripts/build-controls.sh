#!/bin/bash
set -e

PLUGIN_DIR="${1:-.}"
CONTROLS_PATH="${2:-src/controls}"
FULL_PATH="$PLUGIN_DIR/$CONTROLS_PATH"

echo "Building Controls submodule at $FULL_PATH..."

echo "Installing dependencies..."
pnpm --dir "$FULL_PATH" install --frozen-lockfile 2>/dev/null || pnpm --dir "$FULL_PATH" install

echo "Building controls..."
pnpm --dir "$FULL_PATH" run build

echo "Controls build complete."
