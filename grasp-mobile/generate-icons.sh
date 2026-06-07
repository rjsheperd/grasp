#!/bin/bash
# Generate icon-192.png and icon-512.png from the inline SVG.
# Requires: rsvg-convert (apt install librsvg2-bin) or Inkscape.
set -euo pipefail

SVG=$(cat <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="#0f0f0f"/>
  <text x="50" y="68" font-size="58" text-anchor="middle"
        font-family="-apple-system, sans-serif" fill="#5fa87f">G</text>
</svg>
EOF
)

for SIZE in 192 512; do
    echo "$SVG" | rsvg-convert -w "$SIZE" -h "$SIZE" -o "icon-${SIZE}.png"
    echo "Generated icon-${SIZE}.png"
done
