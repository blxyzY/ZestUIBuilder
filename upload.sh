#!/usr/bin/env bash
#
# upload.sh - Upload a build artifact to GoFile.io
#
# Usage:
#   ./upload.sh <path-to-file> [gofile-token]
#
# Notes:
#   - If GOFILE_TOKEN env var is set (or passed as 2nd arg), the file is
#     uploaded to your GoFile account so it shows up in your dashboard.
#     Otherwise it's uploaded anonymously (still gets a shareable link,
#     but you can't manage it later without the token).
#   - Requires: curl, jq
#
set -euo pipefail

FILE_PATH="${1:-}"
TOKEN="${2:-${GOFILE_TOKEN:-}}"

if [[ -z "$FILE_PATH" ]]; then
  echo "Error: no file specified." >&2
  echo "Usage: $0 <path-to-file> [gofile-token]" >&2
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: file not found: $FILE_PATH" >&2
  exit 1
fi

for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found on PATH." >&2
    exit 1
  fi
done

echo "Uploading '$FILE_PATH' to GoFile..."

# 1. Ask GoFile which server to upload to.
SERVER_RESPONSE=$(curl -sS https://api.gofile.io/servers)
SERVER=$(echo "$SERVER_RESPONSE" | jq -r '.data.servers[0].name // empty')

if [[ -z "$SERVER" ]]; then
  echo "Error: could not determine upload server. Response was:" >&2
  echo "$SERVER_RESPONSE" >&2
  exit 1
fi

echo "Using server: $SERVER"

# 2. Upload the file (with token if provided, for account-linked uploads).
if [[ -n "$TOKEN" ]]; then
  UPLOAD_RESPONSE=$(curl -sS \
    -F "file=@${FILE_PATH}" \
    -F "token=${TOKEN}" \
    "https://${SERVER}.gofile.io/uploadFile")
else
  UPLOAD_RESPONSE=$(curl -sS \
    -F "file=@${FILE_PATH}" \
    "https://${SERVER}.gofile.io/uploadFile")
fi

STATUS=$(echo "$UPLOAD_RESPONSE" | jq -r '.status // empty')

if [[ "$STATUS" != "ok" ]]; then
  echo "Error: upload failed. Response was:" >&2
  echo "$UPLOAD_RESPONSE" >&2
  exit 1
fi

DOWNLOAD_PAGE=$(echo "$UPLOAD_RESPONSE" | jq -r '.data.downloadPage // empty')
FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.data.fileId // empty')

echo "Upload successful!"
echo "Download page: $DOWNLOAD_PAGE"
echo "File ID:       $FILE_ID"

# Expose to subsequent CI steps if running under GitHub Actions.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "download_page=${DOWNLOAD_PAGE}"
    echo "file_id=${FILE_ID}"
  } >> "$GITHUB_OUTPUT"
fi
