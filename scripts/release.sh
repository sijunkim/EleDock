#!/bin/bash
# 릴리스: Developer ID 서명·공증·staple·Sparkle appcast·DMG 생성
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGN_ID:?SIGN_ID 가 필요하다 (Developer ID Application 인증서)}"
: "${DOWNLOAD_URL_PREFIX:?DOWNLOAD_URL_PREFIX 가 필요하다}"
: "${SU_FEED_URL:?SU_FEED_URL 가 필요하다 (appcast URL)}"
: "${SU_PUBLIC_ED_KEY:?SU_PUBLIC_ED_KEY 가 필요하다 (generate_keys 공개 키)}"
: "${VERSION:?VERSION 이 필요하다 (예: 1.0.1)}" "${BUILD:?BUILD 가 필요하다 (예: 2)}"
case "$DOWNLOAD_URL_PREFIX" in */) ;; *) DOWNLOAD_URL_PREFIX="$DOWNLOAD_URL_PREFIX/" ;; esac
export SIGN_ID VERSION BUILD SU_FEED_URL SU_PUBLIC_ED_KEY

if [ ! -f "releases/EleDocks-$VERSION.html" ] && [ ! -f "releases/EleDocks-$VERSION.md" ] && [ ! -f "releases/EleDocks-$VERSION.txt" ]; then
    echo "경고: releases/EleDocks-$VERSION.html, .md 또는 .txt 릴리스 노트가 없다" >&2
fi

swift package resolve
KEYCHAIN_ED_KEY=$(.build/artifacts/sparkle/Sparkle/bin/generate_keys -p) || { echo "키체인에 Sparkle 키가 없다 (generate_keys 로 먼저 생성)" >&2; exit 1; }
if [ "$KEYCHAIN_ED_KEY" != "$SU_PUBLIC_ED_KEY" ]; then
    echo "SU_PUBLIC_ED_KEY 가 키체인 공개 키($KEYCHAIN_ED_KEY)와 다르다" >&2
    exit 1
fi

./build.sh

APP=build/EleDocks.app
ZIP=build/EleDocks-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "${NOTARY_PROFILE:-EleDocks}" --wait
xcrun stapler staple "$APP"

mkdir -p releases
rm -f "releases/EleDocks-$VERSION.zip"
ditto -c -k --keepParent "$APP" "releases/EleDocks-$VERSION.zip"
.build/artifacts/sparkle/Sparkle/bin/generate_appcast releases/ --download-url-prefix "$DOWNLOAD_URL_PREFIX" --embed-release-notes

DMG=build/EleDocks-$VERSION.dmg
scripts/make_dmg.sh "$APP" "$DMG"
codesign --timestamp -s "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "${NOTARY_PROFILE:-EleDocks}" --wait
xcrun stapler staple "$DMG"
echo "Released $DMG, releases/EleDocks-$VERSION.zip, releases/appcast.xml"
