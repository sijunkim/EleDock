#!/usr/bin/env python3
"""GitHub 릴리스 다운로드 통계.

GitHub 은 릴리스 파일마다 누적 다운로드 수만 준다. 매일 누적값을 CSV 에 남겨 두면
날짜별·버전별 증가량을 계산할 수 있다(.github/workflows/download-stats.yml 이 매일 collect 를 돌린다).

  python3 scripts/download_stats.py collect --csv downloads.csv   오늘 누적값 기록(같은 날 다시 돌리면 덮어씀)
  python3 scripts/download_stats.py report --csv downloads.csv    날짜별·버전별 증가량 출력

CSV 열: date(UTC), tag, asset, downloads(누적)
"""
import argparse
import csv
import datetime
import json
import os
import sys
import urllib.request
from collections import defaultdict

REPO = "sijunkim/EleDock"
FIELDS = ["date", "tag", "asset", "downloads"]


def fetch_assets():
    rows, page = [], 1
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "eledock-download-stats"}
    token = os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    while True:
        url = f"https://api.github.com/repos/{REPO}/releases?per_page=100&page={page}"
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
            releases = json.load(r)
        if not releases:
            return rows
        for rel in releases:
            for asset in rel["assets"]:
                rows.append((rel["tag_name"], asset["name"], asset["download_count"]))
        page += 1


def read(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def collect(path):
    today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    rows = [r for r in read(path) if r["date"] != today]
    rows += [{"date": today, "tag": t, "asset": a, "downloads": str(n)} for t, a, n in fetch_assets()]
    rows.sort(key=lambda r: (r["date"], r["tag"], r["asset"]))
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"{today}: 파일 {sum(1 for r in rows if r['date'] == today)}개 기록")


def report(path):
    rows = read(path)
    if not rows:
        sys.exit(f"{path}: 기록 없음")
    last = {}  # (tag, asset) → 직전 누적값
    daily = defaultdict(lambda: defaultdict(int))  # date → tag → 증가량
    for r in sorted(rows, key=lambda r: r["date"]):
        key, n = (r["tag"], r["asset"]), int(r["downloads"])
        daily[r["date"]][r["tag"]] += n - last.get(key, n if r["date"] == rows[0]["date"] else 0)
        last[key] = n
    tags = sorted({r["tag"] for r in rows})
    print("date," + ",".join(tags) + ",total")
    for date in sorted(daily):
        values = [daily[date].get(t, 0) for t in tags]
        print(date + "," + ",".join(map(str, values)) + f",{sum(values)}")
    totals = defaultdict(int)
    for (tag, _), n in last.items():
        totals[tag] += n
    print("누적," + ",".join(str(totals[t]) for t in tags) + f",{sum(totals.values())}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["collect", "report"])
    p.add_argument("--csv", required=True)
    a = p.parse_args()
    collect(a.csv) if a.command == "collect" else report(a.csv)


if __name__ == "__main__":
    main()
