#!/bin/bash

set -euo pipefail

# ============================================================
# CodeMono Font Updater
# Repository: https://github.com/tri-nga/CodeMono_Font
# ============================================================

REPO="tri-nga/CodeMono_Font"
FONT_DIR="$HOME/Library/Fonts"

# File dei font da installare
CODEMONO_FONTS=(
    "CodeMono-Regular.ttf"
    "CodeMono-Bold.ttf"
    "CodeMono-Italic.ttf"
    "CodeMono-BoldItalic.ttf"
)

CODEMONO_TERM_FONTS=(
    "CodeMonoTerm-Regular.ttf"
    "CodeMonoTerm-Bold.ttf"
    "CodeMonoTerm-Italic.ttf"
    "CodeMonoTerm-BoldItalic.ttf"
)

# ------------------------------------------------------------
# Utility
# ------------------------------------------------------------

notify() {
    osascript -e "display notification \"$1\" with title \"CodeMono\""
}

error_exit() {
    notify "Aggiornamento fallito: $1"
    echo "ERRORE: $1" >&2
    exit 1
}

# ------------------------------------------------------------
# Controllo dipendenze
# ------------------------------------------------------------

if ! command -v curl >/dev/null 2>&1; then
    error_exit "curl non disponibile."
fi

if ! command -v unzip >/dev/null 2>&1; then
    error_exit "unzip non disponibile."
fi

# ------------------------------------------------------------
# Directory temporanea
# ------------------------------------------------------------

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

# ------------------------------------------------------------
# Recupera informazioni ultima release
# ------------------------------------------------------------

echo "Controllo ultima release..."

RELEASE_JSON="$TMP_DIR/release.json"

if ! curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/releases/latest" \
    -o "$RELEASE_JSON"; then

    error_exit "impossibile raggiungere GitHub."
fi

VERSION="$(python3 -c '
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)

print(data["tag_name"])
' "$RELEASE_JSON")"

echo "Ultima versione disponibile: $VERSION"

# ------------------------------------------------------------
# Trova gli asset
# ------------------------------------------------------------

CODEMONO_URL="$(python3 -c '
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)

for asset in data["assets"]:
    if asset["name"].startswith("CodeMono-") and asset["name"].endswith("-unhinted.zip"):
        print(asset["browser_download_url"])
        break
' "$RELEASE_JSON")"

CODEMONO_TERM_URL="$(python3 -c '
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)

for asset in data["assets"]:
    if asset["name"].startswith("CodeMonoTerm-") and asset["name"].endswith("-unhinted.zip"):
        print(asset["browser_download_url"])
        break
' "$RELEASE_JSON")"

if [[ -z "$CODEMONO_URL" ]]; then
    error_exit "ZIP di CodeMono non trovato nella release $VERSION."
fi

if [[ -z "$CODEMONO_TERM_URL" ]]; then
    error_exit "ZIP di CodeMonoTerm non trovato nella release $VERSION."
fi

# ------------------------------------------------------------
# Download
# ------------------------------------------------------------

CODEMONO_ZIP="$TMP_DIR/CodeMono.zip"
CODEMONO_TERM_ZIP="$TMP_DIR/CodeMonoTerm.zip"

echo "Scarico CodeMono..."
curl -fL "$CODEMONO_URL" -o "$CODEMONO_ZIP"

echo "Scarico CodeMonoTerm..."
curl -fL "$CODEMONO_TERM_URL" -o "$CODEMONO_TERM_ZIP"

# ------------------------------------------------------------
# Estrazione
# ------------------------------------------------------------

CODEMONO_DIR="$TMP_DIR/CodeMono"
CODEMONO_TERM_DIR="$TMP_DIR/CodeMonoTerm"

mkdir -p "$CODEMONO_DIR"
mkdir -p "$CODEMONO_TERM_DIR"

echo "Verifico gli archivi..."

unzip -t "$CODEMONO_ZIP" >/dev/null
unzip -t "$CODEMONO_TERM_ZIP" >/dev/null

echo "Estraggo CodeMono..."
unzip -q "$CODEMONO_ZIP" -d "$CODEMONO_DIR"

echo "Estraggo CodeMonoTerm..."
unzip -q "$CODEMONO_TERM_ZIP" -d "$CODEMONO_TERM_DIR"

# ------------------------------------------------------------
# Verifica che tutti i font esistano PRIMA di cancellare
# quelli vecchi
# ------------------------------------------------------------

for font in "${CODEMONO_FONTS[@]}"; do
    if [[ ! -f "$CODEMONO_DIR/CodeMono/TTF-Unhinted/$font" ]]; then
        error_exit "font mancante nell'archivio CodeMono: $font"
    fi
done

for font in "${CODEMONO_TERM_FONTS[@]}"; do
    if [[ ! -f "$CODEMONO_TERM_DIR/CodeMonoTerm/TTF-Unhinted/$font" ]]; then
        error_exit "font mancante nell'archivio CodeMonoTerm: $font"
    fi
done

# ------------------------------------------------------------
# Crea directory font
# ------------------------------------------------------------

mkdir -p "$FONT_DIR"

# ------------------------------------------------------------
# Rimuove vecchie versioni
# ------------------------------------------------------------

echo "Rimuovo vecchie versioni..."

for font in "${CODEMONO_FONTS[@]}"; do
    rm -f "$FONT_DIR/$font"
done

for font in "${CODEMONO_TERM_FONTS[@]}"; do
    rm -f "$FONT_DIR/$font"
done

# ------------------------------------------------------------
# Installa nuovi font
# ------------------------------------------------------------

echo "Installo CodeMono..."

for font in "${CODEMONO_FONTS[@]}"; do
    cp \
        "$CODEMONO_DIR/CodeMono/TTF-Unhinted/$font" \
        "$FONT_DIR/$font"
done

echo "Installo CodeMonoTerm..."

for font in "${CODEMONO_TERM_FONTS[@]}"; do
    cp \
        "$CODEMONO_TERM_DIR/CodeMonoTerm/TTF-Unhinted/$font" \
        "$FONT_DIR/$font"
done

# ------------------------------------------------------------
# Notifica
# ------------------------------------------------------------

echo
echo "CodeMono $VERSION installato correttamente."

notify "Versione $VERSION installata."
