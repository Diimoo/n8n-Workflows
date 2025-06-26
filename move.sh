#!/usr/bin/env bash
find . \
  -type d \
  -empty \
  -not -path "./.git/*" \
  -exec touch {}/.gitkeep \;
echo "✅ Alle leeren Ordner wurden mit .gitkeep-Dateien versehen."
