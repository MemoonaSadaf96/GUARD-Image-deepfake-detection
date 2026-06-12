#!/usr/bin/env bash
# Start FastAPI + Next.js (same as npm start).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ ! -d node_modules ] || [ ! -d frontend/node_modules ] || [ ! -d .venv ]; then
  echo "Setup incomplete. Run once from project root:"
  echo "  chmod +x setup.sh && ./setup.sh"
  exit 1
fi

bash "$ROOT/scripts/verify-deps.sh"

if [ -d .venv ]; then
  export PATH="$ROOT/.venv/bin:$PATH"
fi

export API_RELOAD="${API_RELOAD:-0}"

exec npm run dev
