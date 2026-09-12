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
  # 1. Prefer a file inside a directory literally named "Output" (case
  #    insensitive) — this is the standard final-output convention for
  #    GSI/ROM build tools like this one, and avoids grabbing intermediate
  #    files from UnpackedROMs/DownloadedROMs.
  for outdir in $(find . -type d -iname "output"); do
    match=$(find "$outdir" -maxdepth 1 -type f \
      \( -name "*.img" -o -name "*.zip" -o -name "*.tar.gz" -o -name "*.bin" \) \
      -print -quit)
    if [[ -n "$match" ]]; then
      BUILD_ARTIFACT="$match"
      break
    fi
  done
fi

if [[ -z "$BUILD_ARTIFACT" ]]; then
  # 2. Fall back to a broader search, but explicitly skip known
  #    intermediate/scratch directories so we don't pick up a temp file.
  BUILD_ARTIFACT=$(find . \
    \( -iname "UnpackedROMs" -o -iname "DownloadedROMs" -o -iname "temp" \) -prune -o \
    -type f \( -name "*.img" -o -name "*.zip" -o -name "*.tar.gz" -o -name "*.bin" \) -print \
    | head -n1)
fi

if [[ -z "$BUILD_ARTIFACT" || ! -f "$BUILD_ARTIFACT" ]]; then
  echo "Error: no build artifact found to upload." >&2
  echo "Set BUILD_ARTIFACT env var, or pass a path: ./release.sh <file>" >&2
  exit 1
fi

echo "Found build artifact: $BUILD_ARTIFACT"
echo "Uploading build result via release.sh..."
echo "Uploading to GoFile..."

bash "$SCRIPT_DIR/upload.sh" "$BUILD_ARTIFACT"
