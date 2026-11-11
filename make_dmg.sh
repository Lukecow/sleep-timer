#!/bin/zsh
# Packages the built app into "Sleep Timer.dmg" (drag-to-Applications installer).
# Run ./build.sh first. The .dmg is written to ./dist
set -e
cd "$(dirname "$0")"
APP="$HOME/Library/Caches/SleepTimer-build/Sleep Timer.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGE="$HOME/Library/Caches/SleepTimer-build/dmg"
mkdir -p dist
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Sleep Timer.app"
ln -s /Applications "$STAGE/Applications"
OUT="dist/Sleep Timer $VERSION.dmg"
rm -f "$OUT"
hdiutil create -volname "Sleep Timer" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT" >/dev/null
rm -rf "$STAGE"
echo "Made $OUT"
