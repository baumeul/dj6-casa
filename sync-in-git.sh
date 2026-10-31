#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync"

# Projektkonfiguration laden
set -a
source .env
set +a

echo "=== Synchronisierung IN ==="

# 1. Git aktualisieren
git pull --ff-only

# 2. Python-Umgebung aktivieren
uv sync