#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync"


echo "=== Synchronisierung OUT ==="

# Umgebungsvariablen laden
set -a
source .env
set +a

#mkdir -p backups
mkdir -p "$ICLOUD_SYNC_DIR"

# 1. Git synchronisieren
git add -A

if ! git diff --cached --quiet; then
    git commit -m "Update $(date '+%Y-%m-%d %H:%M')"
fi

git pull --rebase
git push

# 2. PostgreSQL-Dump erstellen
echo "Erstelle PostgreSQL-Dump ..."
TEMP_DUMP=$(mktemp "$ICLOUD_SYNC_DIR/.dj6-casa.XXXXXX")

trap 'rm -f "$TEMP_DUMP"' EXIT

pg_dump -Fc \
    -U "$DB_USER" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -d "$DB_NAME" \
    -f "$TEMP_DUMP"

# 3. Dump veröffentlichen
mv "$TEMP_DUMP" "$ICLOUD_SYNC_DIR/dj6-casa.dump"

# 4. Prüfsumme erstellen
shasum -a 256 "$ICLOUD_SYNC_DIR/dj6-casa.dump" \
    | awk '{print $1}' > "$ICLOUD_SYNC_DIR/dj6-casa.sha256"

# 5. Zeitstempel dokumentieren
date '+%Y-%m-%d %H:%M:%S' \
    > "$ICLOUD_SYNC_DIR/dj6-casa-info.txt"

echo "Datenbank erfolgreich exportiert."
echo "Bitte iCloud-Synchronisierung abwarten."
echo "=== OUT abgeschlossen ==="
