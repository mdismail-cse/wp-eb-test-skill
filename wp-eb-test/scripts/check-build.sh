#!/bin/bash
# Check if build artifacts are stale or missing
# Usage: check-build.sh <plugin-dir>
# Exit 0 = build needed, Exit 1 = build is fresh

DIR="${1:-.}"

if [ ! -d "$DIR/dist" ] || [ -z "$(ls -A "$DIR/dist/" 2>/dev/null)" ]; then
  echo "BUILD_NEEDED: dist/ missing or empty"
  exit 0
fi

# Portable stat: macOS uses -f '%m', Linux uses -c '%Y'
if stat -f '%m' /dev/null >/dev/null 2>&1; then
  STAT_FMT="-f %m"
else
  STAT_FMT="-c %Y"
fi

NEWEST_SRC=$(find "$DIR/src/" \( -name '*.js' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.scss' -o -name '*.php' \) 2>/dev/null -exec stat $STAT_FMT {} \; 2>/dev/null | sort -rn | head -1)
NEWEST_DIST=$(find "$DIR/dist/" -type f 2>/dev/null -exec stat $STAT_FMT {} \; 2>/dev/null | sort -rn | head -1)

if [ -z "$NEWEST_SRC" ] || [ -z "$NEWEST_DIST" ]; then
  echo "BUILD_NEEDED: could not compare timestamps"
  exit 0
fi

if [ "$NEWEST_SRC" -gt "$NEWEST_DIST" ]; then
  echo "BUILD_NEEDED: source is newer than dist"
  exit 0
fi

echo "BUILD_FRESH"
exit 1
