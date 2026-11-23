#!/bin/sh
set -eu

REPOSITORY="Darkyyto/studykit"
URL="https://github.com/$REPOSITORY/releases/latest/download/Kumo.dmg"
PREVIOUS="FocusKit"
WORK="$(mktemp -d)"
trap 'hdiutil detach -quiet "$WORK/volume" 2>/dev/null || true; rm -rf "$WORK"' EXIT

echo "Downloading Kumo…"
curl -fsSL "$URL" -o "$WORK/Kumo.dmg"

hdiutil attach -quiet -nobrowse -readonly -mountpoint "$WORK/volume" "$WORK/Kumo.dmg"

for name in Kumo "$PREVIOUS"; do
  if pgrep -x "$name" >/dev/null 2>&1; then
    echo "Closing $name…"
    osascript -e "tell application \"$name\" to quit" >/dev/null 2>&1 || true
    waited=0
    while pgrep -x "$name" >/dev/null 2>&1; do
      sleep 0.5
      waited=$((waited + 1))
      if [ "$waited" -eq 10 ]; then
        echo "$name is still open. Quit it with ⌘Q and the installation continues."
      fi
    done
  fi
done

echo "Installing in Applications…"
rm -rf /Applications/Kumo.app
cp -R "$WORK/volume/Kumo.app" /Applications/
xattr -dr com.apple.quarantine /Applications/Kumo.app 2>/dev/null || true
rm -rf "/Applications/$PREVIOUS.app"

open /Applications/Kumo.app
echo "Kumo is ready. Your sessions and lectures are where you left them."
