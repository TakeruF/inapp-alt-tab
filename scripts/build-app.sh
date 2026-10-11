#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="${1:-$PWD/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app="$output_dir/InApp Alt Tab.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/InAppAltTab" "$app/Contents/MacOS/InAppAltTab"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
codesign --force --sign - --identifier dev.takeruf.inapp-alt-tab \
    --requirements '=designated => identifier "dev.takeruf.inapp-alt-tab"' "$app"
codesign --verify --strict "$app"
printf 'Built: %s\n' "$app"
