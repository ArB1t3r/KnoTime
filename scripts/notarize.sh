#!/bin/bash
# Run after build.sh. Credentials remain in the user's Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KNOTIME_SIGN_IDENTITY:?Set your Developer ID Application identity}"
: "${KNOTIME_NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
case "$KNOTIME_SIGN_IDENTITY" in 'Developer ID Application:'*) ;; *) echo 'A Developer ID Application identity is required.' >&2; exit 1;; esac
APP="$PWD/dist/KnoTime.app"
FW="$APP/Contents/Frameworks/Sparkle.framework"
SIGN=(--force --sign "$KNOTIME_SIGN_IDENTITY" --options runtime --timestamp)
codesign "${SIGN[@]}" "$FW/Versions/B/XPCServices/Installer.xpc"
codesign "${SIGN[@]}" --preserve-metadata=entitlements "$FW/Versions/B/XPCServices/Downloader.xpc"
codesign "${SIGN[@]}" "$FW/Versions/B/Autoupdate"
codesign "${SIGN[@]}" "$FW/Versions/B/Updater.app"
codesign "${SIGN[@]}" "$FW"
codesign "${SIGN[@]}" "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p .build/notarization
ditto -c -k --keepParent "$APP" .build/notarization/KnoTime.zip
xcrun notarytool submit .build/notarization/KnoTime.zip --keychain-profile "$KNOTIME_NOTARY_PROFILE" --wait --output-format json > .build/notarization/result.json
python3 - <<'PY'
import json
r=json.load(open('.build/notarization/result.json'))
if r.get('status') != 'Accepted':
    raise SystemExit('Notarization not accepted; inspect .build/notarization/result.json and notarytool log.')
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
printf 'Developer ID signing, notarization, and Gatekeeper checks passed.\n'
