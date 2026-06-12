#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Removing local runtime folders..."
rm -rf .venv node_modules frontend/node_modules frontend/.next

echo "Done."
