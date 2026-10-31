#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Konfiguration
ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync"

# Projektkonfiguration laden
set -a
source .env
set +a

mkdir -p "$ICLOUD_SYNC_DIR"

echo "=== Synchronisierung OUT ==="
# 1. Git synchronisieren
git add -A

if ! git diff --cached --quiet; then
    git commit -m "Update $(date '+%Y-%m-%d %H:%M')"
fi

git pull --rebase
git push