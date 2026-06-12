#!/usr/bin/env bash
# Install OS packages for Image Deepfake Detection on Ubuntu / Debian (incl. 22.04).
# Covers metadata (exiftool), OCR (tesseract), ImageMagick, file/libmagic, and
# libraries needed by OpenCV / TensorFlow wheels.
#
# Usage:  bash scripts/install-analysis-deps-ubuntu.sh
#    or:  ./scripts/install-analysis-deps-ubuntu.sh   (after chmod +x)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Project root: $ROOT"
echo ""

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script targets apt-based systems (Ubuntu/Debian)."
  echo "Install manually: exiftool, imagemagick, tesseract-ocr, file, libmagic1,"
  echo "  python3-venv, nodejs 18+, build-essential, libgl1"
  exit 1
fi

echo "Installing system packages (sudo may ask for your password)..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  git \
  build-essential \
  pkg-config \
  python3 \
  python3-venv \
  python3-pip \
  python3-dev \
  libimage-exiftool-perl \
  imagemagick \
  tesseract-ocr \
  tesseract-ocr-eng \
  file \
  libmagic1 \
  libglib2.0-0 \
  libgl1 \
  libsm6 \
  libxext6 \
  libxrender1 \
  libgomp1 \
  zlib1g-dev

echo ""
echo "Verifying forensic / analysis binaries:"
MISSING=0
for bin in exiftool identify tesseract file python3; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "  OK  $bin -> $(command -v "$bin")"
  else
    echo "  MISSING  $bin"
    MISSING=1
  fi
done

if [ "$MISSING" -ne 0 ]; then
  echo ""
  echo "ERROR: One or more required binaries are still missing after apt install."
  exit 1
fi

echo ""
echo "Optional .env paths (only if tools are not on PATH):"
echo "  EXIFTOOL_PATH=$(command -v exiftool)"
echo "  TESSERACT_PATH=$(command -v tesseract)"
echo ""
echo "Done. Next: ./setup.sh (if you have not finished setup) then npm start"
