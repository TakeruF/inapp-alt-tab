#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
universal=false
signing_identity="-"
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --universal) universal=true; shift ;;
        --sign)
            if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
                printf 'Error: --sign requires a Developer ID Application identity.\n' >&2
                exit 2
            fi
            signing_identity="$2"
            shift 2
            ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done
if [[ $# -gt 1 ]]; then
    printf 'Usage: %s [--universal] [--sign identity] [output-directory]\n' "$0" >&2
    exit 2
fi
output_dir="${1:-$PWD/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
staging_dir="$(mktemp -d "$output_dir/.build-app.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app="$staging_dir/InApp Alt Tab.app"
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
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --sign - --identifier dev.takeruf.inapp-alt-tab \
        --requirements '=designated => identifier "dev.takeruf.inapp-alt-tab"' "$app"
else
    # Keep the certificate-derived designated requirement for stable TCC identity.
    codesign --force --sign "$signing_identity" --options runtime --timestamp "$app"
    signature="$(codesign --display --verbose=4 "$app" 2>&1)"
    if [[ "$signature" != *"Authority=Developer ID Application:"* ]]; then
        printf 'Error: release signing requires a Developer ID Application certificate.\n' >&2
        exit 1
    fi
fi
codesign --verify --strict "$app"
rm -rf "$output_dir/InApp Alt Tab.app"
mv "$app" "$output_dir/InApp Alt Tab.app"
app="$output_dir/InApp Alt Tab.app"
printf 'Built: %s\n' "$app"
