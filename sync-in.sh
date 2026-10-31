#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# iCloud
ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync"

# Umgebungsvariablen laden
set -a
source .env
set +a

echo "=== Synchronisierung IN ==="

# 1. Git aktualisieren
git pull --ff-only

# 2. Python-Umgebung aktivieren
uv sync

# 3. Vorhandenen Datenbank-Dump prüfen
DUMP="$ICLOUD_SYNC_DIR/dj6-casa.dump"
CHECKSUM="$ICLOUD_SYNC_DIR/dj6-casa.sha256"

if [[ ! -f "$DUMP" || ! -f "$CHECKSUM" ]]; then
    echo "Datenbank-Dump oder Prüfsumme fehlt!"
    exit 1
fi

EXPECTED=$(cat "$CHECKSUM")
ACTUAL=$(shasum -a 256 "$DUMP" | awk '{print $1}')

if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "FEHLER: Dump ist unvollständig oder Prüfsumme stimmt nicht!"
    echo "Bitte iCloud-Synchronisierung abwarten."
    exit 1
fi

# 4. Lokales Backup erstellen
BACKUP_DIR="$HOME/Django-Backups"
mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/dj6-casa-$(date '+%Y%m%d-%H%M%S').dump"

echo "Sichere bisherige lokale Datenbank ..."
pg_dump -Fc \
    -U "$DB_USER" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -d "$DB_NAME" \
    -f "$BACKUP_FILE"

# 5. Datenbank neu erstellen
echo "Stelle Datenbank wieder her ..."
dropdb \
    -U "$DB_USER" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    --if-exists "$DB_NAME"

createdb \
    -U "$DB_USER" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -O "$DB_USER" "$DB_NAME"

pg_restore \
    -U "$DB_USER" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -d "$DB_NAME" \
    --no-owner \
    --no-acl \
    "$DUMP"

echo "Datenbank erfolgreich wiederhergestellt."
echo "Lokales Backup: $BACKUP_FILE"
echo "=== IN abgeschlossen ==="


#pg_restore \
#    -U "$DB_USER" \
#    -h "$DB_HOST" \
#    -p "$DB_PORT" \
#    -d dj6-casa \
#    --clean \
#    --if-exists \
#    backups/dj6-casa.dump

#echo "Datenbank wiederhergestellt."

#echo "=== IN abgeschlossen ==="
