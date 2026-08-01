#!/bin/bash
# Builds MScreenshot.app (universal binary) into build/.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
swift build -c release --arch arm64 --arch x86_64

APP=build/MScreenshot.app
BIN=.build/apple/Products/Release/MScreenshot
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MScreenshot"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Prefer the stable "MScreenshot Signing" identity (see setup_signing.sh):
# a constant identity keeps TCC permissions across updates. Fall back to
# any available identity, then ad-hoc.
if [ -z "${SIGN_ID:-}" ]; then
    if security find-identity -v -p codesigning | grep -q "MScreenshot Signing"; then
        SIGN_ID="MScreenshot Signing"
    else
        SIGN_ID="-"
        echo "warning: no signing identity found, using ad-hoc signature." >&2
        echo "         Run scripts/setup_signing.sh once so Screen Recording" >&2
        echo "         permission survives updates." >&2
    fi
fi
codesign --force -s "$SIGN_ID" "$APP"
echo "Built $APP (v$VERSION, signed as: $SIGN_ID)"
