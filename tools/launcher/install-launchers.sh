#!/bin/bash
# Assembles the Articulate 360 and Storyline 360 Dock launchers and the articulate:// URL bridge into ~/Applications (or the folder given as $1).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"; DEST="${1:-$HOME/Applications}"; W="$LAB/wine-patched"
[ -x "$W/bin/wine" ] || { echo "patched Wine mirror missing: build it with tools/wine-build/build-ntdll.sh"; exit 1; }
mkdir -p "$DEST"
make_launcher() { # $1 app name, $2 launcher script, $3 Info.plist, $4 icns
  local A="$DEST/$1.app/Contents"
  rm -rf "$DEST/$1.app"; mkdir -p "$A/MacOS" "$A/Resources"
  cp "$HERE/$3" "$A/Info.plist"; cp "$HERE/$4" "$HERE/storyline-args.sh" "$A/Resources/"
  cp "$HERE/$2" "$A/MacOS/$1"; chmod +x "$A/MacOS/$1"
  # the loader finds ntdll.so through ../lib relative to itself, so the bundle carries a copy plus a lib link to the patched mirror
  cp "$W/bin/wine" "$A/MacOS/wine"; ln -s "$W/lib" "$A/lib"
  echo "built $DEST/$1.app"
}
make_launcher "Articulate 360" launcher.sh Info.plist Articulate360.icns
make_launcher "Storyline 360" storyline-launcher.sh Info-storyline.plist Storyline360.icns
B="$DEST/Articulate360Bridge.app"; P="$B/Contents/Info.plist"
rm -rf "$B"; osacompile -o "$B" "$HERE/../macos-url-bridge/bridge.applescript"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.elearningfreak.articulate360bridge' "$P" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.elearningfreak.articulate360bridge' "$P"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' \
  -c 'Add :CFBundleURLTypes array' -c 'Add :CFBundleURLTypes:0 dict' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLName string Articulate 360 sign-in callback' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string articulate' "$P"
codesign --force --sign - --identifier Articulate360Bridge "$B"
# only the installed copy should claim articulate://, so test builds into other folders are not registered
if [ "$DEST" = "$HOME/Applications" ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$B"
  echo "built $B (registered for articulate://)"
else echo "built $B (not registered; only ~/Applications is)"; fi
