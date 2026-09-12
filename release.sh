#!/usr/bin/env bash
#
# release.sh - Locate the build artifact and hand it off to upload.sh
#
# Usage:
#   ./release.sh [path-to-artifact]
#
# If no path is given, it tries to auto-detect a single artifact in the
# current directory (common build output extensions). Override detection
# by setting BUILD_ARTIFACT or passing the path explicitly.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ARTIFACT="${1:-${BUILD_ARTIFACT:-}}"

if [[ -z "$BUILD_ARTIFACT" ]]; then
  # Adjust these patterns to match whatever your build actually produces
  # (.img for disk/filesystem images, .zip/.tar.gz for packaged builds, etc).
  BUILD_ARTIFACT=$(find . -maxdepth 2 -type f \
    \( -name "*.img" -o -name "*.zip" -o -name "*.tar.gz" -o -name "*.bin" \) \
    -print -quit)
fi

if [[ -z "$BUILD_ARTIFACT" || ! -f "$BUILD_ARTIFACT" ]]; then
  echo "Error: no build artifact found to upload." >&2
  echo "Set BUILD_ARTIFACT env var, or pass a path: ./release.sh <file>" >&2
  exit 1
fi

echo "Uploading build result via release.sh..."
echo "Uploading to GoFile..."

bash "$SCRIPT_DIR/upload.sh" "$BUILD_ARTIFACT"
