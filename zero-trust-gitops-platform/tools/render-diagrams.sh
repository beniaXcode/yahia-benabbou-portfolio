#!/usr/bin/env bash
# Renders every docs/diagrams/src/*.mmd source to a committed SVG at
# docs/diagrams/*.svg via mermaid-cli (mmdc). Sources are the reviewable,
# diffable artifact; SVGs are what the docs site and README actually embed.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="$root/docs/diagrams/src"
out_dir="$root/docs/diagrams"

# v11.17.0 — see docs/versions.md.
mmdc_version="11.17.0"

puppeteer_config="$(mktemp)"
# Only needed when running as root (this sandbox, and most CI containers) —
# Chromium's sandbox itself requires a non-root user or specific kernel
# capabilities neither is guaranteed here.
echo '{"args": ["--no-sandbox"]}' >"$puppeteer_config"
trap 'rm -f "$puppeteer_config"' EXIT

for src in "$src_dir"/*.mmd; do
  name="$(basename "$src" .mmd)"
  echo "==> rendering $name"
  npx --yes "@mermaid-js/mermaid-cli@${mmdc_version}" \
    -i "$src" \
    -o "$out_dir/${name}.svg" \
    -b transparent \
    -p "$puppeteer_config"
done
