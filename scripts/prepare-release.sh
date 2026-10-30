#!/bin/bash
# Produces signed update artifacts locally; does not publish or export keys.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/KnoTime.app"
BIN="$PWD/.build/artifacts/sparkle/Sparkle/bin"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist")
REPO="${KNOTIME_RELEASE_REPO:-ArB1t3r/KnoTime}"
DEST="${1:?Usage: scripts/prepare-release.sh OUTPUT_DIRECTORY}"
mkdir -p "$DEST"
DEST=$(cd "$DEST" && pwd)
codesign --verify --deep --strict "$APP"
EXPECTED_KEY=$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$APP/Contents/Info.plist")
ACTUAL_KEY=$("$BIN/generate_keys" --account app.knotime.mac -p)
if [ "$EXPECTED_KEY" != "$ACTUAL_KEY" ]; then
    echo 'Signing key does not match the public key embedded in the app.' >&2
    exit 1
fi
# ditto preserves framework symlinks and executable permissions.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DEST/KnoTime-$VERSION.zip"
"$BIN/generate_appcast" --account app.knotime.mac --maximum-deltas 0 \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" "$DEST"
python3 - "$DEST/appcast.xml" "$BUILD" <<'PY'
import sys, xml.etree.ElementTree as ET
root=ET.parse(sys.argv[1]).getroot()
ns='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
items=root.findall('./channel/item')
assert any(i.findtext(ns+'version') == sys.argv[2] for i in items), 'Missing current build'
for i in items:
    e=i.find('enclosure')
    assert e is not None and e.get(ns+'edSignature') and int(e.get('length','0')) > 0
    assert e.get('url','').startswith('https://')
print('Signed appcast validated')
PY
printf 'Prepared release %s (build %s) at %s\n' "$VERSION" "$BUILD" "$DEST"
