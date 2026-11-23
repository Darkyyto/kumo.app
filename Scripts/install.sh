#!/bin/sh
set -eu

REPOSITORY="Darkyyto/kumo.app"
URL="https://github.com/$REPOSITORY/releases/latest/download/Kumo.dmg"
WORK="$(mktemp -d)"
trap 'hdiutil detach -quiet "$WORK/volume" 2>/dev/null || true; rm -rf "$WORK"' EXIT

echo "Downloading Kumo…"
curl -fsSL "$URL" -o "$WORK/Kumo.dmg"

hdiutil attach -quiet -nobrowse -readonly -mountpoint "$WORK/volume" "$WORK/Kumo.dmg"

if pgrep -x Kumo >/dev/null 2>&1; then
  echo "Closing Kumo…"
  osascript -e 'tell application "Kumo" to quit' >/dev/null 2>&1 || true
  waited=0
  while pgrep -x Kumo >/dev/null 2>&1; do
    sleep 0.5
    waited=$((waited + 1))
    if [ "$waited" -eq 10 ]; then
      echo "Kumo is still open. Quit it with ⌘Q and the installation continues."
    fi
  done
fi

echo "Installing in Applications…"
rm -rf /Applications/Kumo.app
cp -R "$WORK/volume/Kumo.app" /Applications/
xattr -dr com.apple.quarantine /Applications/Kumo.app 2>/dev/null || true

open /Applications/Kumo.app
echo "Kumo is ready."
