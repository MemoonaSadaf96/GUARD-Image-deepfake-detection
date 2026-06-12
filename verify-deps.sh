#!/usr/bin/env bash
# Quick check before npm start. Run automatically via npm prestart.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ERR=0
warn() { echo "WARNING: $*"; }
fail() { echo "ERROR: $*"; ERR=1; }

if [ ! -d "$ROOT/.venv" ]; then
  fail "Python .venv missing — run: ./setup.sh"
fi

if [ ! -d "$ROOT/node_modules" ] || [ ! -d "$ROOT/frontend/node_modules" ]; then
  fail "Node modules missing — run: ./setup.sh"
fi

if ! command -v node >/dev/null 2>&1; then
  fail "node not found — run: ./setup.sh"
else
  NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  if [ "${NODE_MAJOR:-0}" -lt 18 ] 2>/dev/null; then
    fail "Node.js 18+ required (found $(node -v))"
  fi
fi

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 not found — run: ./setup.sh"
fi

for bin in exiftool tesseract identify file; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    warn "$bin not on PATH — metadata/OCR agents may be skipped. Run: ./setup.sh"
  fi
done

if [ ! -f "$ROOT/.env" ]; then
  warn ".env missing — copy from .env.example and set OPENAI_API_KEY"
elif ! grep -qE '^OPENAI_API_KEY=.+$' "$ROOT/.env" 2>/dev/null; then
  warn "OPENAI_API_KEY not set in .env — Analyze will return 503"
fi

if [ ! -f "$ROOT/models/best_model_effatt.h5" ] && [ ! -L "$ROOT/models/best_model_effatt.h5" ]; then
  if ! grep -qE '^MODEL_REPO_ID=.+' "$ROOT/.env" 2>/dev/null; then
    warn "models/best_model_effatt.h5 missing — add weights or MODEL_REPO_ID in .env"
  fi
fi

if [ "$ERR" -ne 0 ]; then
  echo ""
  echo "Fix the errors above, then run: npm start"
  exit 1
fi

exit 0
