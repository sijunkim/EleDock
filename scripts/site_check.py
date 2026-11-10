#!/usr/bin/env python3
"""공개 상태 점검: 웹사이트 세 언어 페이지, appcast, 최신 릴리스 파일.

문제가 있으면 내용을 출력하고 종료 코드 1 로 끝난다(.github/workflows/site-check.yml 이 실패로 알린다).
릴리스 파일은 다운로드 주소를 직접 열지 않고 GitHub API 로만 확인한다. 열면 다운로드 수가 늘어난다.
  python3 scripts/site_check.py
"""
import json
import os
import re
import sys
import urllib.request

REPO = "sijunkim/EleDock"
SITE = "https://sijunkim.github.io/EleDock/"
PAGES = {"": "en", "ko/": "ko", "ja/": "ja"}
APPCAST = f"https://raw.githubusercontent.com/{REPO}/main/releases/appcast.xml"


def get(url, api=False):
    headers = {"User-Agent": "eledock-site-check"}
    if api:
        headers["Accept"] = "application/vnd.github+json"
        if os.environ.get("GH_TOKEN"):
            headers["Authorization"] = f"Bearer {os.environ['GH_TOKEN']}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
        return r.read().decode("utf-8")


def main():
    problems = []

    for path, lang in PAGES.items():
        try:
            html = get(SITE + path)
            if f'<html lang="{lang}">' not in html:
                problems.append(f"{SITE + path}: <html lang=\"{lang}\"> 없음")
        except Exception as e:
            problems.append(f"{SITE + path}: {e}")

    release = json.loads(get(f"https://api.github.com/repos/{REPO}/releases/latest", api=True))
    version = release["tag_name"].removeprefix("v")
    assets = {a["name"]: a for a in release["assets"]}
    for name in ("EleDock.dmg", f"EleDock-{version}.dmg", f"EleDock-{version}.zip"):
        a = assets.get(name)
        if not a or a["state"] != "uploaded" or a["size"] == 0:
            problems.append(f"{release['tag_name']}: {name} 이 없거나 비었다")

    appcast = get(APPCAST)
    first = re.search(r"<item>(.*?)</item>", appcast, re.S)
    short = re.search(r"<sparkle:shortVersionString>([^<]+)<", first.group(1)) if first else None
    if not short or short.group(1) != version:
        problems.append(f"appcast 첫 항목 버전 {short.group(1) if short else '없음'} ≠ 최신 릴리스 {version}")
    elif first:
        for url, length in re.findall(r'<enclosure url="([^"]+)" (?:[^>]*?)length="(\d+)"', first.group(1)):
            name = url.rsplit("/", 1)[1]
            a = assets.get(name)
            if not a:
                problems.append(f"appcast 의 {name} 이 릴리스에 없다")
            elif a["size"] != int(length):
                problems.append(f"appcast 의 {name} 크기 {length} ≠ 릴리스 {a['size']}")

    if problems:
        print("공개 상태 문제:")
        print("\n".join(f"- {p}" for p in problems))
        sys.exit(1)
    print(f"정상: 웹사이트 {len(PAGES)}개 언어, 최신 릴리스 {release['tag_name']}, appcast {version}")


if __name__ == "__main__":
    main()
