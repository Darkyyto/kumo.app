#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(awk -F'"' '/MARKETING_VERSION/{print $2; exit}' "$ROOT/project.yml")"
WORK="${TMPDIR:-/tmp}/Kumo-release"
DIST="$ROOT/dist"
APP="$WORK/Build/Products/Release/Kumo.app"
DMG="$DIST/Kumo-$VERSION.dmg"
IDENTITY_HASH="71D358801440B0BE64781642ABAAECCD2B23048E"
LEGACY_BUNDLE="FocusKit.app"

rm -rf "$WORK/stage"
mkdir -p "$DIST" "$WORK/stage"

cd "$ROOT"
xcodegen generate --quiet
xcodebuild \
  -project Kumo.xcodeproj \
  -scheme Kumo \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$WORK" \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  -quiet \
  ARCHS="arm64" \
  ONLY_ACTIVE_ARCH=NO \
  build

xattr -cr "$APP"
IDENTITY="-"
KEYCHAIN_ARGS=()
if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then
  IDENTITY="$IDENTITY_HASH"
  KEYCHAIN_ARGS=(--keychain "$SIGNING_KEYCHAIN")
elif [[ -f "$ROOT/signing/build.keychain-db" && -f "$ROOT/signing/p12-password.txt" ]]; then
  security unlock-keychain -p "$(cat "$ROOT/signing/p12-password.txt")" "$ROOT/signing/build.keychain-db"
  IDENTITY="$IDENTITY_HASH"
  KEYCHAIN_ARGS=(--keychain "$ROOT/signing/build.keychain-db")
fi

codesign --force --deep --options runtime "${KEYCHAIN_ARGS[@]}" --sign "$IDENTITY" \
  --entitlements "$ROOT/Kumo/Resources/Kumo.entitlements" "$APP"
codesign --verify --strict "$APP"

ditto "$APP" "$WORK/stage/Kumo.app"
ln -s /Applications "$WORK/stage/Applications"

rm -f "$DMG"
DMGBUILD_BIN="${DMGBUILD:-$(command -v dmgbuild || true)}"
if [[ -n "$DMGBUILD_BIN" && -x "$DMGBUILD_BIN" ]]; then
  # The installer window: pale background, Kumo on the left, an arrow, Applications on the right.
  "$DMGBUILD_BIN" -s "$ROOT/Scripts/dmg/settings.py" -D app="$APP" -D background="$ROOT/Scripts/dmg/background.tiff" "Kumo" "$DMG"
else
  hdiutil create -quiet -volname "Kumo" -srcfolder "$WORK/stage" -ov -format ULFO "$DMG"
fi

cp "$DMG" "$DIST/Kumo.dmg"

rm -f "$DIST/Kumo-$VERSION.zip" "$DIST/Kumo-$VERSION-transition.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Kumo-$VERSION.zip"

rm -rf "$WORK/transition"
mkdir -p "$WORK/transition"
ditto "$APP" "$WORK/transition/$LEGACY_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$WORK/transition/$LEGACY_BUNDLE" "$DIST/Kumo-$VERSION-transition.zip"

echo "App  $(du -sh "$APP" | cut -f1)"
echo "DMG  $(du -h "$DMG" | cut -f1)  $DMG"
