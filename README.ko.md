<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="EleDocks">
</p>

<h1 align="center">EleDocks</h1>

<p align="center"><em>창을 우아하게, Dock으로.</em></p>

<p align="center">
  <a href="https://sijunkim.github.io/EleDocks/?lang=ko"><b>웹사이트</b></a> ·
  <a href="https://github.com/sijunkim/EleDocks/releases/latest/download/EleDocks.dmg"><b>다운로드</b></a> ·
  <a href="README.md">English</a> · 한국어 · <a href="README.ja.md">日本語</a>
</p>

---

EleDocks는 Mac 메뉴 막대에 머무는 작은 앱입니다.
<kbd>⌘</kbd><kbd>M</kbd>으로 창을 하나씩 Dock에 넣고, <kbd>⇧</kbd><kbd>⌘</kbd><kbd>M</kbd>으로 가장 최근 창부터 되돌립니다.

## 하는 일

- **하나씩** — 누를 때마다 맨 앞 창부터 그 뒤의 창까지, 앱을 가리지 않고 하나씩 최소화합니다.
- **순서대로 복원** — 가장 최근에 최소화한 창이 먼저 돌아옵니다.
- **길게 눌러 연속 동작** — 단축키를 누르고 있으면 0.25초마다 창을 하나씩 최소화하거나 복원합니다.
- **원하는 단축키로** — 두 단축키 모두 바꿀 수 있고, 같은 키를 쓰는 실행 중인 앱도 알려 줍니다.
- **제외 앱** — 제외한 앱이 맨 앞에 있으면 그 앱의 단축키가 그대로 동작하고, 그 앱의 창은 건드리지 않습니다.
- **메뉴 막대에서** — 최소화된 창을 확인하고 한 번에 모두 복원합니다. 로그인 시 열 수 있고, 업데이트도 스스로 확인합니다.

## 설치

1. [EleDocks.dmg](https://github.com/sijunkim/EleDocks/releases/latest/download/EleDocks.dmg)를 내려받아 EleDocks를 응용 프로그램 폴더로 끌어 놓습니다.
2. EleDocks를 실행하면 메뉴 막대에 나타납니다.
3. **시스템 설정 › 개인정보 보호 및 보안 › 손쉬운 사용**에서 EleDocks를 켭니다. 다른 앱의 창을 최소화하고 복원하는 데 필요합니다.

macOS 13 Ventura 이상, Apple 실리콘과 Intel Mac에서 동작합니다. Apple의 공증을 거쳤으며 한국어, 영어, 일본어를 지원합니다.

## 소스에서 빌드

```sh
./build.sh          # build/EleDocks.app 생성 (universal)
swift test          # 테스트 실행
```

Swift 6.2가 포함된 Xcode 명령줄 도구가 필요합니다.

## 라이선스

[MIT](LICENSE)
