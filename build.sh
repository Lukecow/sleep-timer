#!/bin/zsh
# Builds "Sleep Timer.app" with the Swift compiler.
# It is built outside Documents (iCloud adds file tags that break code signing).
# Usage: ./build.sh            -> builds to ~/Library/Caches/SleepTimer-build
#        ./build.sh --install  -> also copies it to /Applications and restarts it
set -e
cd "$(dirname "$0")"
OUT="$HOME/Library/Caches/SleepTimer-build"
APP="$OUT/Sleep Timer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Build for Apple-chip and Intel Macs, then join them into one app.
for ARCH in arm64 x86_64; do
  swiftc -O -parse-as-library -swift-version 5 \
    -target $ARCH-apple-macos15.0 \
    Sources/*.swift -o "$OUT/SleepTimer-$ARCH"
done
lipo -create "$OUT/SleepTimer-arm64" "$OUT/SleepTimer-x86_64" -output "$APP/Contents/MacOS/SleepTimer"
rm "$OUT/SleepTimer-arm64" "$OUT/SleepTimer-x86_64"
cp Info.plist "$APP/Contents/Info.plist"
# App icon: with Xcode, compile the modern icon (switches with light/dark mode);
# without Xcode, fall back to the plain light icon.
if xcrun --find actool >/dev/null 2>&1; then
  xcrun actool "$PWD/Icon/AppIcon.icon" --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 15.0 --app-icon AppIcon \
    --output-partial-info-plist "$OUT/icon-partial.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist"
else
  cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
xattr -cr "$APP"
codesign --force --sign - "$APP"
echo "Built $APP"
if [[ "$1" == "--install" ]]; then
  pkill -f "Sleep Timer.app/Contents/MacOS/SleepTimer" || true
  sleep 1
  rm -rf "/Applications/Sleep Timer.app"
  ditto "$APP" "/Applications/Sleep Timer.app"
  open "/Applications/Sleep Timer.app"
  echo "Installed and opened /Applications/Sleep Timer.app"
fi
