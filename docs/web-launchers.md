# Webサイトをアプリ検索から開く

Ubuntuの `Ctrl+Space`（Vicinae）から検索するWebランチャーの正本は
`platforms/ubuntu/applications/*.desktop`。

| 検索名 | 開き方 |
| --- | --- |
| Notion Calendar | Chromeの専用窓（タブ・アドレスバーなし） |
| Google Play Console | Chromeの通常タブ |
| App Store Connect | Chromeの通常タブ |
| RevenueCat | Chromeの通常タブ |
| ChatGPT | Chromeの通常タブ |
| Claude | Chromeの通常タブ |
| Gmail | Chromeの通常タブ |
| Tailscale Admin | Chromeの通常タブ |

Google Chromeがインストール済みの環境で復元する：

```sh
bash scripts/setup-web-launchers.sh
```

`platforms/ubuntu/setup-desktop.sh` からも実行される。
`${XDG_DATA_HOME:-$HOME/.local/share}/applications/` にシンボリックリンクを作り、
既存ファイルがあればバックアップする。再実行可能。
ログイン状態や認証情報は保存せず、そのマシンのChromeプロファイルを使う。

追加するときは同じディレクトリに `.desktop` ファイルを作る。
`Name` が表示名、`Keywords` が検索語、`Exec=google-chrome URL` が通常タブ、
`Exec=google-chrome --app=URL` が専用窓。追加後は上記コマンドを再実行する。
