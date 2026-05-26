#!/usr/bin/env bash
# Start or update the Gitea stack.
# Usage: bash scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in values."
  exit 1
fi

cd "$ROOT_DIR"

echo "==> Pulling latest images"
docker compose pull

echo "==> Starting stack"
docker compose up -d --remove-orphans

echo "==> Stack status"
docker compose ps
