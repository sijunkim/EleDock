#!/bin/bash
# 앱을 Applications 로 끌어 옮기는 배포용 DMG 생성
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP=${1:?app 경로가 필요하다}
OUT=${2:?출력 dmg 경로가 필요하다}

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/EleDocks.app"
rm -f "$OUT"
create-dmg \
    --volname EleDocks \
    --background "$ROOT/Resources/dmg-background.tiff" \
    --window-pos 200 120 \
    --window-size 660 432 \
    --icon-size 128 \
    --icon EleDocks.app 170 210 \
    --hide-extension EleDocks.app \
    --app-drop-link 490 210 \
    --no-internet-enable \
    "$OUT" "$STAGE"
