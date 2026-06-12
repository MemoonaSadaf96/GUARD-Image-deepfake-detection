#!/usr/bin/env bash
# Test-only: add Adobe-style Software/CreatorTool and EXIF dates (22 Apr 2026).
# Use only on images you own. Misrepresenting metadata can mislead others.
#
# Usage:
#   ./scripts/embed-adobe-test-metadata.sh ~/Downloads/"WhatsApp Image 2026-05-11 at 8.49.11 AM.jpeg"
#   ./scripts/embed-adobe-test-metadata.sh INPUT.jpg OUTPUT.jpg
#
# Requires: exiftool

set -euo pipefail

# 22 April 2026 — EXIF datetime format
DATE_EXIF="2026:04:22 12:00:00"

# Strings similar to real Photoshop-exports (adjust if you want another version string)
SOFTWARE="Adobe Photoshop 25.7 (Windows)"
CREATOR="Adobe Photoshop 25.7"

if ! command -v exiftool >/dev/null 2>&1; then
  echo "exiftool not found." >&2
  exit 1
fi

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <input.jpg> [output.jpg]" >&2
  exit 1
fi

IN="$1"
OUT="${2:-}"

if [ ! -f "$IN" ]; then
  echo "Not a file: $IN" >&2
  exit 1
fi

if [ -n "$OUT" ]; then
  cp -f "$IN" "$OUT"
  TARGET="$OUT"
else
  TARGET="$IN"
fi

exiftool -overwrite_original \
  -Software="$SOFTWARE" \
  -XMP:CreatorTool="$CREATOR" \
  -ProcessingSoftware="$SOFTWARE" \
  "-AllDates=$DATE_EXIF" \
  "-EXIF:ModifyDate=$DATE_EXIF" \
  "-EXIF:CreateDate=$DATE_EXIF" \
  "-EXIF:DateTimeOriginal=$DATE_EXIF" \
  "-FileModifyDate=$DATE_EXIF" \
  "$TARGET"

echo "Updated: $TARGET"
echo "--- Software / dates ---"
exiftool -Software -CreatorTool -ProcessingSoftware -ModifyDate -CreateDate -DateTimeOriginal -FileModifyDate "$TARGET"
