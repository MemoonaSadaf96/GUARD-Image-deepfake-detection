#!/usr/bin/env bash
# Install Node.js 20.x on Ubuntu/Debian when missing or older than 18.
# Usage: bash scripts/install-node-ubuntu.sh

set -euo pipefail

need_node() {
  if ! command -v node >/dev/null 2>&1; then
    return 0
  fi
  local major
  major="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  [ "${major:-0}" -lt 18 ] 2>/dev/null
}

if ! need_node; then
  echo "Node.js OK: $(node -v) ($(command -v node))"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "ERROR: Node.js 18+ required but apt-get not found. Install Node manually."
  exit 1
fi

echo "Installing Node.js 20.x via NodeSource (sudo)..."
sudo apt-get install -y ca-certificates curl gnupg
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "Installed: node $(node -v), npm $(npm -v)"
