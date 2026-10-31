# Synchronisation via iCloud und git

## Hintergrund
Eine Django Anwendung mit einer Postgresql Datenbank soll lokal auf mehreren
Macs betrieben werden. Die Synchronisation erfolgt über Git und iCloud.
iCloud wird für die Synchronisierung der Datenbank genutzt. Git wird für
die Django Resourcen genutzt. Zur Synchronisierung werden zwei Bash-Scripts
genutzt: sync-out.sh und sync-in.sh. sync-out.sh erstellt ein Dump der Datenbank
auf der iCloud und schreibt die Django Source nach Git. sync-in.sh liest die
Dumps auf iCloud, löscht die akutelle Datenbank und liest danach den PostgresDump
ein. Damit ist die Postgresql Datenbank synchronisiert. Außerdem wird noch ein
Backup (vor dem Löschen) der aktuellen Datenbank im lokalen Filesystem gesichert.
Schließlich synchronisiert sync-in.sh noch die Django Source aus dem Git Repository.

- iCloud Drive als gemeinsamen Übergabeordner für die PostgreSQL-Datenbank
- Git ausschließlich für den Django-Quellcode.

## Voraussetzungen
- Hombebrew
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

- Postgresql
```
brew update
brew upgrade
brew install postgresql@18
echo 'export PATH="$(brew --prefix postgresql@18)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
brew services start postgresql@18
psql --version
psql postgres
-- List databases
\l
-- List users
\du
-- Create a database
CREATE DATABASE myapp;
-- Connect to database
\c myapp
-- Exit
\q
```

- DBngin
`https://dbngin.com`
alternativ
`$ wget -qO- https://astral.sh/uv/install.sh | sh`

- uv
`$ curl -LsSf https://astral.sh/uv/install.sh | sh`

- Python
```bash
$ uv python install
$ uv python list
$ uv python upgrade
$ uv python upgrade 3.12
```

## Aufgabenteilung:
- Git: Django-Code, Migrationen, requirements.txt
- iCloud Drive: aktueller PostgreSQL-Dump
- Jeder Mac: eigene PostgreSQL-Installation und virtuelle Python-Umgebung

## Verzeichnisstruktur
Auf beiden Macs:
```
Django-Projekt/
├── manage.py
├── requirements.txt
├── .env
├── sync-out.sh
├── sync-in.sh
└── ...

iCloud Drive/
└── Django-Sync/
    ├── db.dump
    └── db-info.txt
```

Der iCloud-Pfad ist auf macOS normalerweise:
`~/Library/Mobile Documents/com~apple~CloudDocs/`

## Konfiguration der Skripte
Beide Skripte verwenden denselben iCloud-Ordner:

`ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync`

## In .env stehen die lokalen PostgreSQL-Zugangsdaten:
```
DB_NAME=dj6-casa
DB_USER=dj6-casa
DB_PASSWORD=dj6-casa
DB_HOST=localhost
DB_PORT=5432
ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync"
```

Das Passwort würde ich nicht in die Skripte schreiben.
Verwende dafür die PostgreSQL-Datei ~/.pgpass auf jedem Mac. Sie muss die Berechtigung 600 haben.

`localhost:5432:dj6-casa:dj6-casa:dj6-casa`

## sync-out.sh – Datenbank und Code exportieren
Diese Version erstellt zunächst den Dump direkt im iCloud-Ordner, benennt
ihn erst nach erfolgreichem Export endgültig um und erzeugt eine Prüfsumme.
Das Script beinhaltet NUR DIE POSTGRES Datenbank und nicht den sync der Django Sourcen.

```
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync"


echo "=== Synchronisierung OUT ==="

# Umgebungsvariablen laden
set -a
source .env
set +a

mkdir -p "$ICLOUD_SYNC_DIR"

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
```

## sync-in.sh – Datenbank und Code importieren
Hier ist mir eine Sicherheitsmaßnahme besonders wichtig:
Bevor die vorhandene Datenbank überschrieben wird, erstellen wir eine lokale Sicherung.
Das Script beinhaltet NUR DIE POSTGRES Datenbank und nicht den sync der Django Sourcen.

```
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# iCloud
ICLOUD_SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Django-Sync"

# Aktuellen Code holen
#git pull --ff-only

# Virtuelle Umgebung aktivieren
#source .venv/bin/activate

# Python-Abhängigkeiten aktualisieren
#pip install -r requirements.txt

# Umgebungsvariablen laden
set -a
source .env
set +a

# Datenbank wiederherstellen
if [ ! -f backups/dj6-casa.dump ]; then
    echo "Datenbank-Dump nicht gefunden!"
    exit 1
fi

echo "=== Synchronisierung IN ==="

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
```

## .gitignore ergänzen
Damit keine Zugangsdaten oder Backups versehentlich in Git landen:
```
.env
.venv/
__pycache__/
*.py[cod]
.DS_Store
```
Der iCloud-Ordner liegt außerhalb des Projektverzeichnisses und wird damit ohnehin nicht von Git erfasst.


## Skripte ausführbar machen
`chmod +x sync-out.sh sync-in.sh`

## Arbeitsablauf
Die Dateien `.env`, `sync-out.sh` und `sync-in.sh` muüssen im Projektordner liegen, also auf gleicher Ebene wie `pyprojects.toml`.

```
Zeitpunkt               Mac A           Mac B
Arbeitsbeginn           ./sync-in.sh
Arbeitsende             ./sync-out.sh
iCloud-Synchronisation  Abwarten
Gerätewechsel
Arbeitsbeginn                           ./sync-in.sh
Arbeitsende                             ./sync-out.sh
```

Starte sync-in.sh auf Mac B erst, wenn iCloud den Upload von Mac A vollständig abgeschlossen hat.
Die Prüfsumme schützt vor unvollständigen oder inkonsistenten Downloads, erkennt aber nicht automatisch, ob ein älterer Dump vorliegt.

## Hinweise:
1. Beende den Django-Server vor sync-out.sh, damit während des Exports keine neuen
Datenbankänderungen erfolgen.
2. Beide Macs sollten möglichst dieselbe PostgreSQL-Hauptversion verwenden.
3. Der PostgreSQL-Benutzer muss die nötigen Rechte zum Löschen und Anlegen der Datenbank besitzen.

Für die erstmalige Einrichtung muss db auf beiden Macs bereits angelegt sein,
bevor du das erste Mal sync-out.sh ausführst.






