#!/usr/bin/env bash
# Embed test metadata: Memoona iPhone, 10 May 2026 dates, Bathers Beach AU GPS.
# Use only on images you own. Forged metadata can mislead.
#
# Usage:
#   ./scripts/embed-memoona-bathers-may10.sh ~/Downloads/"WhatsApp Image 2026-05-10 at 8.54.19 PM.jpeg"
#     -> writes ~/Downloads/camera-bathers.jpeg (default output name)
#   ./scripts/embed-memoona-bathers-may10.sh INPUT.jpg /other/path/out.jpg
#
# Requires: exiftool

set -euo pipefail

# 10 May 2026 (Date modified / EXIF times)
DATE_EXIF="2026:05:10 12:00:00"

# Camera as requested
MAKE="Memoona"
MODEL="iPhone"

# Bathers Beach area, Perth region WA (approx. GPS pin)
LAT_S="32.0583"
LON_E="115.7417"

if ! command -v exiftool >/dev/null 2>&1; then
  echo "exiftool not found." >&2
  exit 1
fi

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <input.jpg> [output.jpg]" >&2
  echo "  Default output: \$HOME/Downloads/camera-bathers.jpeg" >&2
  exit 1
fi

IN="$1"
OUT="${2:-}"

if [ ! -f "$IN" ]; then
  echo "Not a file: $IN" >&2
  exit 1
fi

DOWNLOADS="${HOME}/Downloads"
DEFAULT_OUT="${DOWNLOADS}/camera-bathers.jpeg"

if [ -n "$OUT" ]; then
  cp -f "$IN" "$OUT"
  TARGET="$OUT"
else
  mkdir -p "$DOWNLOADS"
  cp -f "$IN" "$DEFAULT_OUT"
  TARGET="$DEFAULT_OUT"
fi

exiftool -overwrite_original \
  "-EXIF:Make=$MAKE" \
  "-EXIF:Model=$MODEL" \
  "-IFD0:Make=$MAKE" \
  "-IFD0:Model=$MODEL" \
  "-AllDates=$DATE_EXIF" \
  "-EXIF:ModifyDate=$DATE_EXIF" \
  "-EXIF:CreateDate=$DATE_EXIF" \
  "-EXIF:DateTimeOriginal=$DATE_EXIF" \
  "-FileModifyDate=$DATE_EXIF" \
  -GPSLatitude="${LAT_S}" -GPSLatitudeRef=S \
  -GPSLongitude="${LON_E}" -GPSLongitudeRef=E \
  -XMP:Location="Bathers Beach" \
  -XMP:City="Perth" \
  -XMP:State="Western Australia" \
  -XMP:Country="Australia" \
  "$TARGET"

echo "Updated: $TARGET"
echo "--- Make / Model / dates / GPS / place ---"
exiftool -Make -Model -ModifyDate -CreateDate -DateTimeOriginal -FileModifyDate \
  -GPSLatitude -GPSLongitude -GPSPosition -Location -City -State -Country "$TARGET"
