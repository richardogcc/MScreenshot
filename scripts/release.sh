#!/bin/bash
# Builds the app, packages it as a DMG into dist/ and creates a GitHub release
# for the version in VERSION. Releases are pushed manually — run this locally.
# Usage: scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="MScreenshot"
VERSION=$(cat VERSION)

./scripts/build_app.sh

mkdir -p dist
DMG="dist/$NAME-$VERSION.dmg"
rm -f "$DMG"

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "build/$NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$NAME $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
echo "Packaged $DMG"

# Release notes: the CHANGELOG.md entry for this version.
NOTES=$(awk -v v="$VERSION" '
    $0 ~ "^## " v { found = 1; next }
    /^## / && found { exit }
    found { print }
' CHANGELOG.md)

gh release create "v$VERSION" "$DMG" \
    --title "$NAME $VERSION" \
    --notes "${NOTES:-$NAME $VERSION}"
echo "Release v$VERSION published."
