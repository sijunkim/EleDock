#!/bin/bash
# 배포: 사전 점검 → release.sh → 커밋·태그 → GitHub 릴리스 → main push → 공개 URL 검증
set -euo pipefail
cd "$(dirname "$0")/.."

REPO=sijunkim/EleDock
FEED_URL=https://raw.githubusercontent.com/$REPO/main/releases/appcast.xml
PAGES_URL=https://sijunkim.github.io/EleDock/
SIGN_ID=${SIGN_ID:-"Developer ID Application: SiJun Kim (V7HD5GU452)"}
GENERATE_KEYS=.build/artifacts/sparkle/Sparkle/bin/generate_keys
# 공증 API 키 설정(NOTARY_KEY·NOTARY_KEY_ID·NOTARY_ISSUER). 저장소 밖에 두고 있으면 읽는다
NOTARY_ENV=${NOTARY_ENV:-$HOME/.eledock-secrets/notary.env}
if [ -f "$NOTARY_ENV" ]; then
    # shellcheck disable=SC1090
    . "$NOTARY_ENV"
    export NOTARY_KEY NOTARY_KEY_ID NOTARY_ISSUER
fi
APPCAST_WAIT_SECONDS=600
URL_WAIT_SECONDS=120
RETRY_INTERVAL_SECONDS=20

usage() {
    echo "사용법: scripts/publish.sh <VERSION> [--dry-run]" >&2
    exit 2
}
fail() {
    echo "중단: $*" >&2
    exit 1
}

VERSION=""
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -*) usage ;;
        *) if [ -n "$VERSION" ]; then usage; fi; VERSION=$arg ;;
    esac
done
[ -n "$VERSION" ] || usage
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION 은 x.y.z 형식이어야 한다: $VERSION"

TAG=v$VERSION
NOTES=releases/EleDock-$VERSION.md
ZIP=releases/EleDock-$VERSION.zip
DMG=build/EleDock-$VERSION.dmg
ALIAS_DMG=build/EleDock.dmg

# 진행 단계: 0 사전 점검, 1 release.sh, 2 커밋, 3 로컬 태그, 4 태그 push, 5 GitHub 릴리스, 6 main push, 7 공개 URL 검증
STEP=0
BASE_COMMIT=""
RELEASE_COMMIT=""

step_name() {
    case "$1" in
        1) echo "release.sh(빌드·서명·공증·appcast)" ;;
        2) echo "릴리스 커밋" ;;
        3) echo "로컬 태그 생성" ;;
        4) echo "태그 push" ;;
        5) echo "GitHub 릴리스 생성" ;;
        6) echo "main push" ;;
        *) echo "공개 URL 검증" ;;
    esac
}

# 실패하면 어디까지 됐는지와 복구 명령을 출력한다(실행하지 않는다)
on_exit() {
    local code=$?
    if [ "$code" -eq 0 ] || [ "$STEP" -eq 0 ]; then return; fi
    {
        echo
        echo "실패: '$(step_name "$STEP")' 단계에서 멈췄다(종료 코드 $code). 이 단계는 일부만 됐을 수 있다."
        echo "복구 명령(위에서부터 해당하는 것만 실행):"
        if [ "$STEP" -ge 7 ]; then
            echo "  - 릴리스는 이미 공개됐다. raw.githubusercontent 캐시 때문일 수 있으니 몇 분 뒤 위 URL 을 직접 다시 확인한다. 되돌리려면 아래를 실행한다"
        fi
        if [ "$STEP" -ge 6 ]; then
            echo "  - main 이 push 됐으면(git fetch && git log -1 origin/main 으로 확인) 공개된 appcast 되돌리기: git revert --no-edit $RELEASE_COMMIT && git push origin main"
        fi
        if [ "$STEP" -ge 5 ]; then
            echo "  - GitHub 릴리스 삭제: gh release delete $TAG --repo $REPO --yes"
        fi
        if [ "$STEP" -ge 4 ]; then
            echo "  - 원격 태그 삭제: git push origin :refs/tags/$TAG"
        fi
        if [ "$STEP" -ge 3 ]; then
            echo "  - 로컬 태그 삭제: git tag -d $TAG"
        fi
        if [ "$STEP" -ge 2 ]; then
            echo "  - main 이 push 되지 않았으면 릴리스 커밋 취소(노트 파일은 남는다): git reset $BASE_COMMIT"
        fi
        echo "  - appcast 되돌리기(main 이 push 되지 않았을 때): git checkout -- releases/appcast.xml"
        echo "  - build/ 와 releases/*.zip, releases/*.delta 는 git 미추적이라 그대로 둬도 된다"
    } >&2
}
trap on_exit EXIT
trap 'exit 130' INT TERM

echo "사전 점검: $VERSION"

ORIGIN_URL=$(git remote get-url origin) || fail "origin 원격이 없다"
[[ "$ORIGIN_URL" =~ github\.com[:/]sijunkim/EleDock(\.git)?$ ]] || fail "origin 이 $REPO 가 아니다: $ORIGIN_URL"
[ "$(git symbolic-ref --short -q HEAD || true)" = main ] || fail "현재 브랜치가 main 이 아니다"

if [ ! -x "$GENERATE_KEYS" ]; then swift package resolve; fi
SU_PUBLIC_ED_KEY=$("$GENERATE_KEYS" -p) || fail "키체인에 Sparkle 키가 없다(generate_keys 로 먼저 만든다)"
[ -n "$SU_PUBLIC_ED_KEY" ] || fail "generate_keys -p 출력이 비었다"

DIRTY=""
while IFS= read -r line; do
    if [ "${line:3}" != "$NOTES" ]; then DIRTY="$DIRTY  $line"$'\n'; fi
done < <(git status --porcelain --untracked-files=all)
[ -z "$DIRTY" ] || fail "작업 트리에 $NOTES 외의 변경이 있다(dry-run 뒤라면 git checkout -- releases/appcast.xml):"$'\n'"$DIRTY"

git fetch --quiet origin main || fail "origin main 을 가져오지 못했다(새 저장소에 main 이 push 돼 있어야 한다)"
BASE_COMMIT=$(git rev-parse HEAD)
[ "$BASE_COMMIT" = "$(git rev-parse origin/main)" ] || fail "main 이 origin/main 과 다르다"

[ -f "$NOTES" ] || fail "$NOTES 가 없다"
SEPARATORS=$(grep -c -x -e '---' "$NOTES" || true)
SECTIONS=$(awk '/^---$/ { if (body) n++; body = 0; next } NF { body = 1 } END { if (body) n++; print n + 0 }' "$NOTES")
if ! { [ "$SEPARATORS" -eq 2 ] && [ "$SECTIONS" -eq 3 ]; }; then
    fail "$NOTES 는 '---' 로 구분된 en·ko·ja 3개 섹션이어야 한다(구분선 $SEPARATORS개, 내용 있는 섹션 $SECTIONS개)"
fi

if git rev-parse -q --verify "refs/tags/$TAG" > /dev/null; then fail "로컬 태그 $TAG 가 이미 있다"; fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" > /dev/null; then
    fail "원격 태그 $TAG 가 이미 있다"
else
    rc=$?
    [ "$rc" -eq 2 ] || fail "원격 태그를 확인하지 못했다(git ls-remote 종료 코드 $rc)"
fi

gh auth status --hostname github.com > /dev/null 2>&1 || fail "gh 로그인이 필요하다(gh auth login)"
if RELEASE_VIEW=$(gh release view "$TAG" --repo "$REPO" --json tagName 2>&1); then
    fail "GitHub 릴리스 $TAG 가 이미 있다"
fi
case "$RELEASE_VIEW" in
    *"release not found"*) ;;
    *) fail "GitHub 릴리스를 확인하지 못했다: $RELEASE_VIEW" ;;
esac

LAST_BUILD=$(sed -n 's|.*<sparkle:version>\([0-9][0-9]*\)</sparkle:version>.*|\1|p' releases/appcast.xml | sort -n | tail -1)
BUILD=$((${LAST_BUILD:-0} + 1))

IDENTITIES=$(security find-identity -v -p codesigning)
case "$IDENTITIES" in
    *"\"$SIGN_ID\""*) ;;
    *) fail "키체인에 서명 ID 가 없다: $SIGN_ID" ;;
esac

if [ -n "${NOTARY_KEY:-}" ]; then
    [ -f "$NOTARY_KEY" ] || fail "공증 API 키 파일이 없다: $NOTARY_KEY"
    xcrun notarytool history --key "$NOTARY_KEY" --key-id "${NOTARY_KEY_ID:-}" --issuer "${NOTARY_ISSUER:-}" > /dev/null 2>&1 \
        || fail "공증 API 키로 인증하지 못했다($NOTARY_ENV 확인)"
else
    xcrun notarytool history --keychain-profile "${NOTARY_PROFILE:-EleDock}" > /dev/null 2>&1 \
        || fail "공증 키체인 프로필 ${NOTARY_PROFILE:-EleDock} 로 인증하지 못했다(notarytool store-credentials 또는 $NOTARY_ENV 준비)"
fi

[ ! -e /Volumes/EleDock ] || fail "/Volumes/EleDock 이 이미 마운트돼 있다(꺼낸 뒤 다시 실행)"

echo "사전 점검 통과: VERSION=$VERSION BUILD=$BUILD TAG=$TAG"

STEP=1
SIGN_ID=$SIGN_ID SU_FEED_URL=$FEED_URL SU_PUBLIC_ED_KEY=$SU_PUBLIC_ED_KEY \
    DOWNLOAD_URL_PREFIX=https://github.com/$REPO/releases/download/$TAG/ \
    VERSION=$VERSION BUILD=$BUILD scripts/release.sh
FIRST_BUILD=$(sed -n 's|.*<sparkle:version>\([0-9][0-9]*\)</sparkle:version>.*|\1|p' releases/appcast.xml | sed -n 1p)
[ "$FIRST_BUILD" = "$BUILD" ] || fail "releases/appcast.xml 첫 항목이 BUILD $BUILD 가 아니다('$FIRST_BUILD')"

ASSETS=("$DMG" "$ALIAS_DMG" "$ZIP")
for delta in releases/EleDock"$BUILD"-*.delta; do
    if [ -e "$delta" ]; then ASSETS+=("$delta"); fi
done

if [ "$DRY_RUN" -eq 1 ]; then
    STEP=0
    echo
    echo "dry-run 끝: 서명·공증은 실제로 했다. 커밋·태그·push·GitHub 릴리스는 하지 않았다."
    echo "만든 파일:"
    for f in "${ASSETS[@]}"; do echo "  $f ($(stat -f%z "$f") bytes)"; done
    echo "releases/appcast.xml 변경:"
    git --no-pager diff -- releases/appcast.xml
    echo
    echo "실제 배포 전에 appcast 를 되돌려야 한다(되돌리지 않으면 사전 점검에서 막힌다):"
    echo "  git checkout -- releases/appcast.xml"
    echo "그다음: scripts/publish.sh $VERSION"
    exit 0
fi

STEP=2
git add -- releases/appcast.xml "$NOTES"
git commit --quiet -m "release: $VERSION" -- releases/appcast.xml "$NOTES"
RELEASE_COMMIT=$(git rev-parse HEAD)

STEP=3
git tag -a "$TAG" -m "release: $VERSION"

STEP=4
git push origin "refs/tags/$TAG"

STEP=5
gh release create "$TAG" --repo "$REPO" --verify-tag --latest \
    --title "EleDock $VERSION" --notes-file "$NOTES" "${ASSETS[@]}"

STEP=6
git push origin main

STEP=7
echo "공개 URL 검증(인증 없이)"

fetch() {
    env -u GH_TOKEN -u GITHUB_TOKEN curl -sL --max-time 300 "$@"
}
# 받은 바이트 수로 상태 코드와 크기를 확인한다: expect_download <URL> <크기>
expect_download() {
    local got
    got=$(fetch -o /dev/null -w '%{http_code} %{size_download}' "$1") || got="curl 실패"
    if [ "$got" = "200 $2" ]; then
        echo "  확인: $1 ($2 bytes)"
    else
        echo "  불일치: $1 (기대 200 $2, 실제 $got)" >&2
        return 1
    fi
}
check_appcast() {
    local first
    APPCAST_BODY=$(fetch "$FEED_URL?nocache=$(date +%s)") || return 1
    first=$(sed -n 's|.*<sparkle:version>\([0-9][0-9]*\)</sparkle:version>.*|\1|p' <<< "$APPCAST_BODY" | sed -n 1p)
    if [ "$first" = "$BUILD" ]; then
        echo "  확인: 공개 appcast 첫 sparkle:version $BUILD"
    else
        echo "  대기: 공개 appcast 첫 sparkle:version 이 '$first'" >&2
        return 1
    fi
}
check_enclosures() {
    local enclosure url length count=0 failed=0
    while IFS= read -r enclosure; do
        count=$((count + 1))
        url=$(sed -n 's/.* url="\([^"]*\)".*/\1/p' <<< "$enclosure")
        length=$(sed -n 's/.* length="\([^"]*\)".*/\1/p' <<< "$enclosure")
        expect_download "$url" "$length" || failed=1
    done < <(grep -o '<enclosure [^>]*>' <<< "$APPCAST_BODY" || true)
    [ "$count" -gt 0 ] || { echo "  불일치: appcast 에 enclosure 가 없다" >&2; return 1; }
    return "$failed"
}
check_latest_dmg() {
    expect_download "https://github.com/$REPO/releases/latest/download/EleDock.dmg" "$(stat -f%z "$DMG")"
}
check_latest_tag() {
    local tag
    tag=$(fetch "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')
    if [ "$tag" = "$TAG" ]; then
        echo "  확인: releases/latest tag_name $TAG"
    else
        echo "  불일치: releases/latest tag_name '$tag'" >&2
        return 1
    fi
}
check_pages() {
    local code
    code=$(fetch -o /dev/null -w '%{http_code}' "$PAGES_URL") || code="curl 실패"
    if [ "$code" = 200 ]; then
        echo "  확인: $PAGES_URL"
    else
        echo "  불일치: $PAGES_URL ($code)" >&2
        return 1
    fi
}
# 성공할 때까지 다시 확인한다: retry <초> <함수>
retry() {
    local deadline=$((SECONDS + $1))
    while ! "$2"; do
        if [ "$SECONDS" -ge "$deadline" ]; then return 1; fi
        sleep "$RETRY_INTERVAL_SECONDS"
    done
}

FAILED=""
APPCAST_BODY=""
if retry "$APPCAST_WAIT_SECONDS" check_appcast; then
    retry "$URL_WAIT_SECONDS" check_enclosures || FAILED="$FAILED enclosure"
else
    FAILED="$FAILED appcast"
fi
retry "$URL_WAIT_SECONDS" check_latest_dmg || FAILED="$FAILED latest-dmg"
retry "$URL_WAIT_SECONDS" check_latest_tag || FAILED="$FAILED latest-tag"
retry "$URL_WAIT_SECONDS" check_pages || FAILED="$FAILED pages"
[ -z "$FAILED" ] || fail "공개 URL 검증 실패:$FAILED"

STEP=0
echo "배포 완료: EleDock $VERSION (BUILD $BUILD)"
