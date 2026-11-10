#!/bin/bash
# EleDock.app(arm64 + x86_64 universal)을 build/ 에 만든다.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${VERSION:-0.0.0}
BUILD=${BUILD:-0}
SIGN_ID=${SIGN_ID:-}
SU_FEED_URL=${SU_FEED_URL:-}
SU_PUBLIC_ED_KEY=${SU_PUBLIC_ED_KEY:-}
if [ -n "$SU_FEED_URL" ] && [ -z "$SU_PUBLIC_ED_KEY" ]; then
    echo "SU_FEED_URL 이 있으면 SU_PUBLIC_ED_KEY 도 필요하다" >&2
    exit 1
fi

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

APP=build/EleDock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
# arm64 슬라이스의 SDK 빌드 버전을 현재 SDK 로 올린다.
SDK_VERSION=$(xcrun --show-sdk-version)
vtool -arch arm64 -set-build-version macos 13.0 "$SDK_VERSION" -replace \
    -output "$APP/Contents/MacOS/EleDock" "$BIN/EleDock"
strip -S -x "$APP/Contents/MacOS/EleDock"
ditto "$BIN/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/dmg-background.tiff "$APP/Contents/Resources/dmg-background.tiff"
LOCALIZATIONS=""
for lproj in Resources/*.lproj; do
    cp -R "$lproj" "$APP/Contents/Resources/"
    LOCALIZATIONS+="<string>$(basename "$lproj" .lproj)</string>"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>EleDock</string>
    <key>CFBundleIdentifier</key><string>com.sijunkim.eledock</string>
    <key>CFBundleName</key><string>EleDock</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array>$LOCALIZATIONS</array>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>SUEnableAutomaticChecks</key><true/>
</dict>
</plist>
PLIST
if [ -n "$SU_FEED_URL" ]; then
    plutil -insert SUFeedURL -string "$SU_FEED_URL" "$APP/Contents/Info.plist"
fi
if [ -n "$SU_PUBLIC_ED_KEY" ]; then
    plutil -insert SUPublicEDKey -string "$SU_PUBLIC_ED_KEY" "$APP/Contents/Info.plist"
fi
plutil -lint "$APP/Contents/Info.plist"

sign() {
    if [ -n "$SIGN_ID" ]; then
        codesign -f -o runtime --timestamp -s "$SIGN_ID" "$@"
    else
        codesign -f -s - "$@"
    fi
}
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
if [ -n "$SIGN_ID" ]; then
    sign "$APP"
else
    sign -r='designated => identifier "com.sijunkim.eledock"' "$APP"
fi
echo "Built $APP"
