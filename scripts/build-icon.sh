#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep the generated master intact; iconutil packages all standard macOS sizes.
source_icon="Resources/Icon/AppIcon.png"
icon_work="$(mktemp -d)"
trap 'rm -rf "$icon_work"' EXIT
iconset="$icon_work/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source_icon" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$source_icon" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
printf 'Built: Resources/AppIcon.icns\n'
