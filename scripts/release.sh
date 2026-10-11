#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Secrets stay in Keychain or Xcode's account storage. Never pass passwords here.
action="${1:-}"
signing_identity="${DEVELOPER_ID_APPLICATION:-}"
profile="${NOTARY_KEYCHAIN_PROFILE:-}"
version="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
release_dir="$PWD/dist/$version"
archive="$release_dir/InAppAltTab.xcarchive"
app="$release_dir/InApp Alt Tab.app"
zip="$release_dir/InApp-Alt-Tab-$version-universal.zip"

case "$action" in
    prepare)
        if [[ -z "$signing_identity" ]]; then
            printf 'Set DEVELOPER_ID_APPLICATION to a Developer ID Application certificate name or SHA-1.\n' >&2
            exit 2
        fi
        # Never overwrite a submitted archive; finish can be retried independently.
        if [[ -e "$archive" || -e "$release_dir/submission.json" ]]; then
            printf 'An existing submission is present in %s; run finish or use a new version.\n' "$release_dir" >&2
            exit 2
        fi
        swift test
        bash scripts/build-app.sh --universal --sign "$signing_identity" "$release_dir"
        if [[ -n "$profile" ]]; then
            ditto -c -k --keepParent "$app" "$release_dir/notarization-upload.zip"
            xcrun notarytool submit "$release_dir/notarization-upload.zip" \
                --keychain-profile "$profile" --output-format json > "$release_dir/submission-pending.json"
            mv "$release_dir/submission-pending.json" "$release_dir/submission.json"
            # Record the method without storing credentials.
            printf 'notarytool\n' > "$release_dir/notarization-method.txt"
            cat "$release_dir/submission.json"
        else
            # A standard archive lets Xcode use an already configured developer account.
            mkdir -p "$archive/Products/Applications"
            ditto "$app" "$archive/Products/Applications/InApp Alt Tab.app"
            python3 - "$app" "$archive" "$release_dir" <<'PY'
import datetime, pathlib, plistlib, re, subprocess, sys
app, archive, output = map(pathlib.Path, sys.argv[1:])
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
signature = subprocess.run(['codesign', '-d', '--verbose=4', str(app)],
                           capture_output=True, text=True, check=True).stderr
team = re.search(r'^TeamIdentifier=(\w+)$', signature, re.M).group(1)
identity = re.search(r'^Authority=(Developer ID Application:.+)$', signature, re.M).group(1)
archive_info = {
    'ArchiveVersion': 2, 'CreationDate': datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),
    'Name': info['CFBundleName'], 'SchemeName': 'InAppAltTab',
    'ApplicationProperties': {
        'ApplicationPath': 'Applications/InApp Alt Tab.app',
        'CFBundleIdentifier': info['CFBundleIdentifier'],
        'CFBundleShortVersionString': info['CFBundleShortVersionString'],
        'CFBundleVersion': info['CFBundleVersion'], 'SigningIdentity': identity, 'Team': team,
    },
}
(archive / 'Info.plist').write_bytes(plistlib.dumps(archive_info))
(output / 'ExportOptions-Notarize.plist').write_bytes(plistlib.dumps({
    'method': 'developer-id', 'destination': 'upload', 'signingStyle': 'manual',
    'signingCertificate': identity, 'teamID': team,
}))
PY
            printf 'xcode\n' > "$release_dir/notarization-method.txt"
            xcodebuild -exportArchive -archivePath "$archive" \
                -exportPath "$release_dir/notarization-upload" \
                -exportOptionsPlist "$release_dir/ExportOptions-Notarize.plist" \
                -allowProvisioningUpdates
        fi
        printf 'Submitted %s. Run bash scripts/release.sh finish after Apple processing completes.\n' "$version"
        ;;
    finish)
        method="$(cat "$release_dir/notarization-method.txt")"
        case "$method" in
            notarytool)
                if [[ -z "$profile" ]]; then
                    printf 'Set NOTARY_KEYCHAIN_PROFILE to the profile used for prepare.\n' >&2
                    exit 2
                fi
                submission_id="$(plutil -extract id raw "$release_dir/submission.json")"
                xcrun notarytool wait "$submission_id" --keychain-profile "$profile" \
                    --timeout 50s --output-format json > "$release_dir/notarization-status.json"
                xcrun notarytool log "$submission_id" --keychain-profile "$profile" \
                    "$release_dir/notarization-log.json"
                if [[ "$(plutil -extract status raw "$release_dir/notarization-status.json")" != Accepted ]]; then
                    printf 'Notarization was not accepted; inspect notarization-log.json.\n' >&2
                    exit 1
                fi
                xcrun stapler staple "$app"
                ;;
            xcode)
                export_dir="$(mktemp -d "$release_dir/.notarized.XXXXXX")"
                trap 'rm -rf "$export_dir"' EXIT
                xcodebuild -exportNotarizedApp -archivePath "$archive" -exportPath "$export_dir"
                codesign --verify --strict "$export_dir/InApp Alt Tab.app"
                xcrun stapler validate "$export_dir/InApp Alt Tab.app"
                rm -rf "$app"
                ditto "$export_dir/InApp Alt Tab.app" "$app"
                ;;
            *) printf 'Unknown notarization method: %s\n' "$method" >&2; exit 1 ;;
        esac
        codesign --verify --strict "$app"
        xcrun stapler validate "$app"
        spctl --assess --type execute --verbose=2 "$app"
        # Package only after stapling, so the downloadable app carries its ticket.
        ditto -c -k --keepParent "$app" "$zip"
        (cd "$release_dir" && shasum -a 256 "$(basename "$zip")" > SHA256SUMS.txt)
        printf 'Notarized release: %s\n' "$zip"
        ;;
    *) printf 'Usage: %s prepare|finish\n' "$0" >&2; exit 2 ;;
esac
