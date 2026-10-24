#!/bin/bash
# 앱을 Applications 로 끌어 옮기는 배포용 DMG 생성
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP=${1:?app 경로가 필요하다}
OUT=${2:?출력 dmg 경로가 필요하다}
VENV="$ROOT/build/dmg-venv"

WORK=$(mktemp -d)
MOUNT=""
cleanup() {
    if [ -n "$MOUNT" ]; then hdiutil detach -quiet -force "$MOUNT" || true; fi
    rm -rf "$WORK"
}
trap cleanup EXIT

if ! "$VENV/bin/python" -c "import ds_store" 2>/dev/null; then
    rm -rf "$VENV"
    /usr/bin/python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q --disable-pip-version-check ds_store==1.3.1 mac_alias==2.2.2
fi

mkdir "$WORK/stage"
ditto "$APP" "$WORK/stage/EleDocks.app"
ln -s /Applications "$WORK/stage/Applications"
hdiutil create -quiet -volname EleDocks -fs HFS+ -format UDRW -srcfolder "$WORK/stage" "$WORK/rw.dmg"
MOUNT=$(hdiutil attach -nobrowse -noautoopen "$WORK/rw.dmg" | awk -F'\t' '/Apple_HFS/ {print $NF}')
if [ "$MOUNT" != /Volumes/EleDocks ]; then
    echo "$MOUNT 에 붙었다. 이미 붙은 EleDocks 볼륨을 꺼내고 다시 실행한다" >&2
    exit 1
fi
SetFile -a E "$MOUNT/EleDocks.app"
"$VENV/bin/python" "$ROOT/scripts/make_dmg_ds_store.py" "$MOUNT"
rm -rf "$MOUNT/.fseventsd"
hdiutil detach -quiet "$MOUNT"
MOUNT=""
rm -f "$OUT"
hdiutil convert -quiet "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$OUT"
