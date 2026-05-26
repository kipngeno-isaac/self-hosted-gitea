#!/usr/bin/env bash
# Create a timestamped backup of Gitea data and PostgreSQL.
# Usage: bash scripts/backup.sh [/path/to/backup/dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${1:-$ROOT_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"
cd "$ROOT_DIR"

echo "==> Backing up Gitea data to $BACKUP_DIR/gitea-$TIMESTAMP.tar.gz"
tar -czf "$BACKUP_DIR/gitea-$TIMESTAMP.tar.gz" gitea-data/

echo "==> Dumping PostgreSQL database"
docker exec gitea-db pg_dump -U gitea gitea \
  > "$BACKUP_DIR/gitea-db-$TIMESTAMP.sql"
gzip "$BACKUP_DIR/gitea-db-$TIMESTAMP.sql"

echo "==> Backup complete:"
ls -lh "$BACKUP_DIR/gitea-$TIMESTAMP.tar.gz" "$BACKUP_DIR/gitea-db-$TIMESTAMP.sql.gz"

# Prune backups older than 30 days
find "$BACKUP_DIR" -name "gitea-*.tar.gz" -mtime +30 -delete
find "$BACKUP_DIR" -name "gitea-db-*.sql.gz" -mtime +30 -delete
