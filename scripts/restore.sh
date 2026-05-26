#!/usr/bin/env bash
# Restore Gitea from a backup.
# Usage: bash scripts/restore.sh <gitea-TIMESTAMP.tar.gz> <gitea-db-TIMESTAMP.sql.gz>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

DATA_BACKUP="${1:?Usage: $0 <gitea-data.tar.gz> <gitea-db.sql.gz>}"
DB_BACKUP="${2:?Usage: $0 <gitea-data.tar.gz> <gitea-db.sql.gz>}"

cd "$ROOT_DIR"

echo "==> Stopping stack"
docker compose down

echo "==> Restoring Gitea data"
rm -rf gitea-data/
tar -xzf "$DATA_BACKUP"

echo "==> Restoring database"
docker compose up -d postgres
sleep 5
gunzip -c "$DB_BACKUP" | docker exec -i gitea-db psql -U gitea -d gitea

echo "==> Starting full stack"
docker compose up -d

echo "==> Restore complete"
docker compose ps
