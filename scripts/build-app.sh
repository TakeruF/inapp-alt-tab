#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
universal=false
if [[ "${1:-}" == "--universal" ]]; then
    universal=true
    shift
fi
if [[ $# -gt 1 ]]; then
    printf 'Usage: %s [--universal] [output-directory]\n' "$0" >&2
    exit 2
fi
output_dir="${1:-$PWD/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
app="$output_dir/InApp Alt Tab.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
if "$universal"; then
    binaries=()
    for arch in arm64 x86_64; do
        build_args=(-c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/universal/$arch")
        swift build "${build_args[@]}"
        binary_dir="$(swift build "${build_args[@]}" --show-bin-path)"
        binaries+=("$binary_dir/InAppAltTab")
    done
    lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/InAppAltTab"
else
    swift build -c release
    binary_dir="$(swift build -c release --show-bin-path)"
    cp "$binary_dir/InAppAltTab" "$app/Contents/MacOS/InAppAltTab"
fi
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
ditto "$binary_dir/InAppAltTab_AppLocalization.bundle" "$app/Contents/Resources/InAppAltTab_AppLocalization.bundle"
for localization in Resources/*.lproj; do
    ditto "$localization" "$app/Contents/Resources/$(basename "$localization")"
done
codesign --force --sign - --identifier dev.takeruf.inapp-alt-tab \
    --requirements '=designated => identifier "dev.takeruf.inapp-alt-tab"' "$app"
codesign --verify --strict "$app"
printf 'Built: %s\n' "$app"
