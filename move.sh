#!/usr/bin/env bash
set -euo pipefail

SRC=~/aura-pwa/project
DST=~/aura-pwa

# Dateimapping als "Quelle:Ziel"-Paare
declare -A map=(
  [".gitignore"]=".gitignore"
  ["extensions.json"]=".vscode/extensions.json"
  ["README.md"]="README.md"
  ["package.json"]="${DST}/package.json"
  ["App.vue"]="aura_frontend/src/App.vue"
  ["AudioRecorder.vue"]="aura_frontend/src/components/AudioRecorder.vue"
  ["HelloWorld.vue"]="aura_frontend/src/components/HelloWorld.vue"
  ["PdfGenerator.vue"]="aura_frontend/src/components/PdfGenerator.vue"
  ["TranscriptionDisplay.vue"]="aura_frontend/src/components/TranscriptionDisplay.vue"
  ["style.css"]="aura_frontend/src/style.css"
  ["main.js"]="aura_frontend/src/main.js"
  ["index.html"]="aura_frontend/index.html"
  ["package.json"]="aura_frontend/package.json"
  ["vite.config.js"]="aura_frontend/vite.config.js"
  ["favicon.ico"]="aura_frontend/public/favicon.ico"
  ["manifest.json"]="aura_frontend/public/manifest.json"
  ["main.py"]="aura_backend/app/main.py"
  ["requirements.txt"]="aura_backend/requirements.txt"
)

cd "$SRC"
for src in "${!map[@]}"; do
  dest_rel=${map[$src]}
  dest="$DST/$dest_rel"
  mkdir -p "$(dirname "$dest")"
  mv -v "$src" "$dest"
done
