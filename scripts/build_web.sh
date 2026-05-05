#!/usr/bin/env bash
# Build a Goske web release and stage public/ assets next to it.
# Run from the project root:  bash scripts/build_web.sh
#
# Prerequisites:
#   - Godot 4.6+ on PATH ("godot" command resolvable)
#   - Web export template installed via Godot Editor:
#       Editor → Manage Export Templates → Download and Install
#   - The "Web" preset exists in export_presets.cfg (it does, committed)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT_DIR="web"
mkdir -p "$OUT_DIR"

echo "[build] godot --export-release Web → $OUT_DIR/index.html"
godot --headless --path . --export-release "Web" "$OUT_DIR/index.html"

if [ -d public ]; then
  echo "[build] copying public/ → $OUT_DIR/"
  cp -R public/. "$OUT_DIR/"
fi

echo
echo "[build] Done. Files:"
ls -lh "$OUT_DIR" | head -20
echo
echo "Next:  wrangler pages deploy $OUT_DIR --project-name goske"
echo "(or drag-drop $OUT_DIR/ in the Cloudflare Pages dashboard)"
