#!/usr/bin/env bash
# One-time setup on Ubuntu / Linux (fresh 22.04: installs system tools, Node, Python venv).
#
#   chmod +x setup.sh
#   ./setup.sh
#   # edit .env → OPENAI_API_KEY
#   npm start

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

FRESH=0
if [ "${1:-}" = "--fresh" ]; then
  FRESH=1
fi

# Fix CRLF from Windows zip (safe no-op on Linux-created files)
for f in setup.sh start.sh scripts/*.sh; do
  [ -f "$f" ] && sed -i 's/\r$//' "$f" 2>/dev/null || true
done

echo "=============================================="
echo " Image Deepfake Detection — setup"
echo " Project: $ROOT"
echo "=============================================="
echo ""

chmod +x setup.sh start.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true

if [ "$FRESH" = "1" ]; then
  echo ">> Fresh setup requested: removing copied runtime folders (.venv, node_modules, frontend/.next)"
  rm -rf .venv node_modules frontend/node_modules frontend/.next
  echo ""
fi

# --- Ubuntu / Debian: system packages + Node 20 if needed ---
if [ "${INSTALL_OS:-1}" = "1" ] && command -v apt-get >/dev/null 2>&1; then
  echo ">> Step 1/5: System packages (exiftool, tesseract, ImageMagick, Python, …)"
  bash "$ROOT/scripts/install-analysis-deps-ubuntu.sh"
  echo ""
  echo ">> Step 2/5: Node.js 18+ (if needed)"
  bash "$ROOT/scripts/install-node-ubuntu.sh"
  echo ""
else
  echo ">> Skipping apt / NodeSource install (INSTALL_OS=0 or not Debian/Ubuntu)."
  echo "   Ensure you have: node 18+, npm, python3 3.10+, exiftool, tesseract, imagemagick, file"
  echo ""
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' is not installed. On Ubuntu 22 run: ./setup.sh"
    exit 1
  fi
}

need_cmd node
need_cmd npm
need_cmd python3

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [ "${NODE_MAJOR}" -lt 18 ] 2>/dev/null; then
  echo "ERROR: Node.js 18+ required (found $(node -v))."
  exit 1
fi

PY_MINOR="$(python3 -c 'import sys; print(sys.version_info.minor)')"
if [ "$(python3 -c 'import sys; print(sys.version_info.major)')" -lt 3 ] || [ "$PY_MINOR" -lt 10 ]; then
  echo "ERROR: Python 3.10+ required (found $(python3 --version))."
  exit 1
fi

echo ">> Step 3/5: Environment files"
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "   Created .env from .env.example — add OPENAI_API_KEY before Analyze."
  else
    echo "   WARNING: No .env.example found."
  fi
else
  echo "   .env already exists (unchanged)."
fi

if [ ! -f frontend/.env.local ] && [ -f frontend/.env.local.example ]; then
  cp frontend/.env.local.example frontend/.env.local
  echo "   Created frontend/.env.local from example."
fi

if [ -f .env ] && ! grep -qE '^FORCE_CPU_INFERENCE=' .env 2>/dev/null; then
  {
    echo ""
    echo "# Added automatically by setup.sh for portable CPU-only inference."
    echo "FORCE_CPU_INFERENCE=1"
  } >> .env
  echo "   Added FORCE_CPU_INFERENCE=1 to .env (portable default)."
fi
echo ""

echo ">> Step 4/5: Node packages (root + frontend)…"
npm run install:all
echo ""

echo ">> Step 5/5: Python virtualenv + pip packages (several minutes)…"
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
# shellcheck source=/dev/null
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r api/requirements.txt
deactivate 2>/dev/null || true
echo ""

if [ -f models/best_model_effatt.h5 ] || [ -L models/best_model_effatt.h5 ]; then
  echo ">> Model weights: found models/best_model_effatt.h5"
elif grep -qE '^MODEL_REPO_ID=.+' .env 2>/dev/null; then
  echo ">> Model weights: will download on first analyze (MODEL_REPO_ID in .env)."
else
  echo "WARNING: No models/best_model_effatt.h5"
  echo "         Copy your .h5 into models/ or set MODEL_REPO_ID in .env"
fi
echo ""

echo ">> Verifying tools on PATH:"
for bin in exiftool tesseract identify file; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "   OK  $bin"
  else
    echo "   MISSING  $bin (re-run ./setup.sh or install manually)"
  fi
done
echo ""

bash "$ROOT/scripts/verify-deps.sh" || true

if [ -f models/best_model_effatt.h5 ] || grep -qE '^MODEL_REPO_ID=.+' .env 2>/dev/null; then
  echo ""
  echo ">> Verifying local detector can load on this PC..."
  # shellcheck source=/dev/null
  source .venv/bin/activate
  python scripts/verify-local-model.py || true
  deactivate 2>/dev/null || true
fi

echo "=============================================="
echo " Setup finished."
echo ""
echo " 1. Edit .env → set OPENAI_API_KEY (required for Analyze)"
echo " 2. Start the app:"
echo "      npm start"
echo "   For a clean rebuild on another PC:"
echo "      ./setup.sh --fresh"
echo ""
echo " Web UI:  http://127.0.0.1:3000"
echo " API:     http://127.0.0.1:8000"
echo "=============================================="
