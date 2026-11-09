<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="EleDocks">
</p>

<h1 align="center">EleDocks</h1>

<p align="center"><em>ウインドウを、エレガントに Dock へ。</em></p>

<p align="center">
  <a href="https://sijunkim.github.io/EleDocks/?lang=ja"><b>Web サイト</b></a> ·
  <a href="https://github.com/sijunkim/EleDocks/releases/latest/download/EleDocks.dmg"><b>ダウンロード</b></a> ·
  <a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · 日本語
</p>

---

EleDocks は、Mac のメニューバーに置く小さなアプリです。
<kbd>⌘</kbd><kbd>M</kbd> でウインドウを1つずつ Dock にしまい、<kbd>⇧</kbd><kbd>⌘</kbd><kbd>M</kbd> で最後にしまったものから戻します。

## できること

- **1つずつ** — 押すたびに、前面のウインドウからその後ろへ、アプリを問わず1つずつしまいます。
- **順番どおりに復元** — 最後にしまったウインドウから戻ります。
- **長押しで連続** — ショートカットを押し続けると、0.25秒ごとにウインドウを1つずつしまうか復元します。
- **好きなキーで** — どちらのショートカットも変更でき、同じキーを使っている実行中のアプリも表示します。
- **除外アプリ** — 除外したアプリが最前面にあるときは、そのアプリのショートカットがそのまま使え、そのウインドウには触れません。
- **メニューバーから** — しまったウインドウを確認し、まとめて復元できます。ログイン時に開き、自動でアップデートします。

## インストール

1. [EleDocks.dmg](https://github.com/sijunkim/EleDocks/releases/latest/download/EleDocks.dmg) をダウンロードし、EleDocks を“アプリケーション”フォルダにドラッグします。
2. EleDocks を開くと、メニューバーに表示されます。
3. **システム設定 › プライバシーとセキュリティ › アクセシビリティ** で EleDocks をオンにします。ほかのアプリのウインドウをしまったり戻したりするために必要です。

macOS 13 Ventura 以降の Apple シリコン搭載 Mac と Intel 搭載 Mac で動作します。Apple による署名と公証を受けており、日本語・英語・韓国語に対応しています。

## ソースからビルド

```sh
./build.sh          # build/EleDocks.app を作成 (universal)
swift test          # テストを実行
```

Swift 6.2 を含む Xcode コマンドラインツールが必要です。

## ライセンス

[MIT](LICENSE)
