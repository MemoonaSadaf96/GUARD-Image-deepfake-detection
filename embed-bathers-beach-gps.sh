#!/usr/bin/env bash
# Embed GPS EXIF for Bathers Beach, Fremantle WA (published ballpark pin).
# Decimal: 32.0583 S, 115.7417 E
#
# Usage:
#   ./scripts/embed-bathers-beach-gps.sh path/to/photo.jpg
#   ./scripts/embed-bathers-beach-gps.sh path/to/photo.jpg path/to/output.jpg
#
# Requires: exiftool (see scripts/install-analysis-deps-ubuntu.sh)

set -euo pipefail

LAT_S="32.0583"
LON_E="115.7417"

if ! command -v exiftool >/dev/null 2>&1; then
  echo "exiftool not found. Install exiftool or run: ./scripts/install-analysis-deps-ubuntu.sh" >&2
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
  -GPSLatitude="${LAT_S}" -GPSLatitudeRef=S \
  -GPSLongitude="${LON_E}" -GPSLongitudeRef=E \
  "$TARGET"

echo "GPS written to: $TARGET"
exiftool -gps:all -n "$TARGET"
