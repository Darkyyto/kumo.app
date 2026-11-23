#!/bin/zsh
set -euo pipefail

NAME="Kumo"
ROOT="${0:A:h:h}"
VERSION="$(awk -F'"' '/MARKETING_VERSION/{print $2; exit}' "$ROOT/project.yml")"
WORK="${TMPDIR:-/tmp}/$NAME-release"
DIST="$ROOT/dist"
APP="$WORK/Build/Products/Release/$NAME.app"
DMG="$DIST/$NAME-$VERSION.dmg"
IDENTITY_HASH="71D358801440B0BE64781642ABAAECCD2B23048E"

rm -rf "$WORK/stage"
mkdir -p "$DIST" "$WORK/stage"

cd "$ROOT"
xcodegen generate --quiet
xcodebuild \
  -project "$NAME.xcodeproj" \
  -scheme "$NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$WORK" \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  -quiet \
  ARCHS="arm64 x86_64" \
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
  --entitlements "$ROOT/$NAME/Resources/$NAME.entitlements" "$APP"
codesign --verify --strict "$APP"

ditto "$APP" "$WORK/stage/$NAME.app"
ln -s /Applications "$WORK/stage/Applications"

rm -f "$DMG"
DMGBUILD_BIN="${DMGBUILD:-$(command -v dmgbuild || echo "$HOME/Library/Caches/dmgbuild-venv/bin/dmgbuild")}"
if [[ -x "$DMGBUILD_BIN" ]]; then
  # The installer window: graphite page, the app on the left, an arrow, Applications on the right.
  "$DMGBUILD_BIN" -s "$ROOT/Scripts/dmg/settings-single.py" -D app="$APP" -D background="$ROOT/Scripts/dmg/background-kumo.tiff" "$NAME" "$DMG"
else
  echo "warning: dmgbuild not found, making a plain disk image. Install it with: pip3 install dmgbuild" >&2
  hdiutil create -quiet -volname "$NAME" -srcfolder "$WORK/stage" -ov -format ULFO "$DMG"
fi

cp "$DMG" "$DIST/$NAME.dmg"
rm -rf "$DIST/$NAME.app"
ditto "$APP" "$DIST/$NAME.app"

rm -f "$DIST/$NAME-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$NAME-$VERSION.zip"

echo "App  $(du -sh "$APP" | cut -f1)"
echo "DMG  $(du -h "$DMG" | cut -f1)  $DMG"
