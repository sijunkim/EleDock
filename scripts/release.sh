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
# 공증 인증: NOTARY_KEY(App Store Connect API 키 .p8)·NOTARY_KEY_ID·NOTARY_ISSUER 가 있으면 키 파일을 직접 쓰고,
# 없으면 키체인 프로필(NOTARY_PROFILE, 기본 EleDock)을 쓴다
if [ -n "${NOTARY_KEY:-}" ]; then
    : "${NOTARY_KEY_ID:?NOTARY_KEY 를 쓰면 NOTARY_KEY_ID 도 필요하다}" "${NOTARY_ISSUER:?NOTARY_KEY 를 쓰면 NOTARY_ISSUER 도 필요하다}"
    NOTARY_AUTH=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
else
    NOTARY_AUTH=(--keychain-profile "${NOTARY_PROFILE:-EleDock}")
fi

if [ ! -f "releases/EleDock-$VERSION.html" ] && [ ! -f "releases/EleDock-$VERSION.md" ] && [ ! -f "releases/EleDock-$VERSION.txt" ]; then
    echo "경고: releases/EleDock-$VERSION.html, .md 또는 .txt 릴리스 노트가 없다" >&2
fi
! grep -q "<sparkle:version>$BUILD</sparkle:version>" releases/appcast.xml || { echo "releases/appcast.xml 에 BUILD $BUILD 항목이 이미 있다" >&2; exit 1; }

swift package resolve
KEYCHAIN_ED_KEY=$(.build/artifacts/sparkle/Sparkle/bin/generate_keys -p) || { echo "키체인에 Sparkle 키가 없다 (generate_keys 로 먼저 생성)" >&2; exit 1; }
if [ "$KEYCHAIN_ED_KEY" != "$SU_PUBLIC_ED_KEY" ]; then
    echo "SU_PUBLIC_ED_KEY 가 키체인 공개 키($KEYCHAIN_ED_KEY)와 다르다" >&2
    exit 1
fi

./build.sh

APP=build/EleDock.app
ZIP=build/EleDock-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" "${NOTARY_AUTH[@]}" --wait
xcrun stapler staple "$APP"

mkdir -p releases
rm -f "releases/EleDock-$VERSION.zip"
ditto -c -k --keepParent "$APP" "releases/EleDock-$VERSION.zip"
STAGE=build/appcast
rm -rf "$STAGE" && mkdir "$STAGE"
cp releases/*.zip releases/EleDock-"$VERSION".* "$STAGE"/
.build/artifacts/sparkle/Sparkle/bin/generate_appcast "$STAGE" --download-url-prefix "$DOWNLOAD_URL_PREFIX" --embed-release-notes --maximum-versions 1
if compgen -G "$STAGE/*.delta" > /dev/null; then cp "$STAGE"/*.delta releases/; fi
NEW_ITEM=$(awk '/<item>/ { f = 1 } f { print } /<\/item>/ { exit }' "$STAGE/appcast.xml")
APPCAST=$(NEW_ITEM="$NEW_ITEM" awk '(/<item>/ || /<\/channel>/) && !done { print ENVIRON["NEW_ITEM"]; done = 1 } 1' releases/appcast.xml)
printf '%s\n' "$APPCAST" > releases/appcast.xml

DMG=build/EleDock-$VERSION.dmg
scripts/make_dmg.sh "$APP" "$DMG"
codesign --timestamp -s "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" "${NOTARY_AUTH[@]}" --wait
xcrun stapler staple "$DMG"
# 웹사이트·README 의 releases/latest/download/EleDock.dmg 가 가리키는 버전 없는 이름
cp "$DMG" build/EleDock.dmg
echo "Released $DMG, build/EleDock.dmg, releases/EleDock-$VERSION.zip, releases/appcast.xml"
