#!/bin/bash
# Only publishes artifacts that have passed Apple notarization.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KNOTIME_NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
NOTES="${1:?Usage: scripts/publish-release.sh RELEASE_NOTES_FILE}"
NOTES=$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$NOTES")
test -s "$NOTES"
APP="$PWD/dist/KnoTime.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
REPO="${KNOTIME_RELEASE_REPO:-ArB1t3r/KnoTime}"
STAGE="$PWD/.build/release-stage/$VERSION"
OUT="$PWD/release/$VERSION"
# Never publish an ad-hoc or unstapled build by accident.
SIGNATURE_INFO=$(codesign --display --verbose=4 "$APP" 2>&1)
grep -q '^Authority=Developer ID Application:' <<< "$SIGNATURE_INFO"
codesign --verify --deep --strict "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute "$APP"
mkdir -p "$STAGE" "$OUT"
ditto "$APP" "$STAGE/KnoTime.app"
ln -sfn /Applications "$STAGE/Applications"
hdiutil create -volname KnoTime -srcfolder "$STAGE" -ov -format UDZO "$OUT/KnoTime.dmg"
xcrun notarytool submit "$OUT/KnoTime.dmg" --keychain-profile "$KNOTIME_NOTARY_PROFILE" --wait --output-format json > "$OUT/notarization.json"
python3 - "$OUT/notarization.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1])).get('status') == 'Accepted', 'DMG notarization failed'
PY
xcrun stapler staple "$OUT/KnoTime.dmg"
xcrun stapler validate "$OUT/KnoTime.dmg"
# Feed uses a zip of the stapled app. Keep the DMG outside the feed directory.
mkdir -p "$OUT/update"
./scripts/prepare-release.sh "$OUT/update"
python3 - "$OUT" "$VERSION" <<'PYHASH'
import hashlib, pathlib, sys
root=pathlib.Path(sys.argv[1])
files=[root/'KnoTime.dmg', root/'update'/f'KnoTime-{sys.argv[2]}.zip']
(root/'SHA256SUMS').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in files))
PYHASH
# All assets upload while draft; only then does /latest advance.
gh release create "v$VERSION" --repo "$REPO" --draft --title "KnoTime $VERSION" --notes-file "$NOTES" \
    "$OUT/KnoTime.dmg" "$OUT/update/KnoTime-$VERSION.zip" "$OUT/update/appcast.xml" "$OUT/SHA256SUMS"
gh release edit "v$VERSION" --repo "$REPO" --draft=false --latest
