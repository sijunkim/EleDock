#!/usr/bin/env python3
"""웹사이트 생성: scripts/site/template.html + strings.json → docs/index.html, docs/ko/, docs/ja/, docs/sitemap.xml

언어마다 문구를 미리 넣은 정적 페이지를 만들어 검색엔진이 언어별로 읽게 한다.
문구는 strings.json 만 고치고 이 스크립트를 다시 돌린다.
  python3 scripts/make_site.py          생성
  python3 scripts/make_site.py --check  생성 결과가 docs/ 와 같은지 확인(다르면 종료 코드 1)
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "scripts" / "site"
DOCS = ROOT / "docs"
BASE_URL = "https://sijunkim.github.io/EleDock/"
DOWNLOAD_URL = "https://github.com/sijunkim/EleDock/releases/latest/download/EleDock.dmg"

# (언어, docs 안 경로, og:locale). 첫 항목이 기본(x-default) 페이지다.
PAGES = [("en", "", "en_US"), ("ko", "ko/", "ko_KR"), ("ja", "ja/", "ja_JP")]

# 첫 페이지에서만: 고른 언어(?lang=, 저장한 값) 또는 브라우저 언어가 ko·ja 면 그 페이지로 넘긴다.
REDIRECT = """<script>
(function () {
  var pages = { ko: "ko/", ja: "ja/" };
  var pick = new URLSearchParams(location.search).get("lang");
  if (!pick) { try { pick = localStorage.getItem("lang"); } catch (e) {} }
  if (!pick) {
    var list = navigator.languages || [navigator.language || "en"];
    for (var i = 0; i < list.length; i++) {
      var code = String(list[i]).slice(0, 2).toLowerCase();
      if (code === "en" || pages[code]) { pick = code; break; }
    }
  }
  if (pages[pick]) location.replace(pages[pick]);
})();
</script>"""


def render(template, strings, lang, path, locale):
    t = strings[lang]
    alternates = [f'<link rel="alternate" hreflang="{code}" href="{BASE_URL}{p}">' for code, p, _ in PAGES]
    alternates.append(f'<link rel="alternate" hreflang="x-default" href="{BASE_URL}">')
    jsonld = {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "EleDock",
        "description": t["meta.description"],
        "inLanguage": lang,
        "operatingSystem": "macOS 13 or later",
        "applicationCategory": "UtilitiesApplication",
        "url": BASE_URL + path,
        "downloadUrl": DOWNLOAD_URL,
        "image": BASE_URL + "icon.png",
        "license": "https://opensource.org/licenses/MIT",
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
    }
    values = {
        "lang": lang,
        "locale": locale,
        "url": BASE_URL + path,
        "base": "../" * path.count("/") or "./",
        **t,
    }
    raw = {
        "alternates": "\n".join(alternates),
        "jsonld": json.dumps(jsonld, ensure_ascii=False, indent=2),
        "redirect": REDIRECT if path == "" else "",
        **{f"current.{code}": ' aria-current="page"' if code == lang else "" for code, _, _ in PAGES},
    }

    def sub(m):
        name = m.group(2)
        table = raw if m.group(1) else values
        if name not in table:
            sys.exit(f"{lang}: 자리표시 {{{{{m.group(1)}{name}}}}} 값이 없다")
        return table[name] if m.group(1) else html.escape(table[name], quote=True)

    out = re.sub(r"\{\{(!?)([a-z0-9._]+)\}\}", sub, template)
    # 빈 raw 자리표시가 남긴 빈 줄 정리
    return re.sub(r"\n\n+(?=<link rel=\"icon\")", "\n", out)


def sitemap():
    links = "".join(
        f'\n    <xhtml:link rel="alternate" hreflang="{code}" href="{BASE_URL}{p}"/>' for code, p, _ in PAGES
    )
    urls = "".join(f"\n  <url>\n    <loc>{BASE_URL}{p}</loc>{links}\n  </url>" for _, p, _ in PAGES)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">'
        f"{urls}\n</urlset>\n"
    )


def main():
    check = sys.argv[1:] == ["--check"]
    if sys.argv[1:] and not check:
        sys.exit(__doc__)
    template = (SITE / "template.html").read_text(encoding="utf-8")
    strings = json.loads((SITE / "strings.json").read_text(encoding="utf-8"))
    keys = set(strings["en"])
    for lang, _, _ in PAGES:
        if set(strings[lang]) != keys:
            sys.exit(f"strings.json: {lang} 키가 en 과 다르다: {sorted(set(strings[lang]) ^ keys)}")
    stale = []
    outputs = [(DOCS / path / "index.html", render(template, strings, lang, path, locale)) for lang, path, locale in PAGES]
    outputs.append((DOCS / "sitemap.xml", sitemap()))
    for target, page in outputs:
        if check:
            if not target.exists() or target.read_text(encoding="utf-8") != page:
                stale.append(str(target.relative_to(ROOT)))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(page, encoding="utf-8")
            print(target.relative_to(ROOT))
    if stale:
        sys.exit("생성 결과와 다르다(python3 scripts/make_site.py 로 다시 생성): " + ", ".join(stale))


if __name__ == "__main__":
    main()
