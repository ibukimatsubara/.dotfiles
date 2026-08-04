# skhd 設定

macOSでよく使うアプリをグローバルショートカットから開くために、skhdを使用します。

## インストール

```bash
brew install skhd
skhd --start-service
```

`setup.sh`は`skhdrc`を`~/.skhdrc`へリンクし、サービスを起動します。

## ショートカット

| ショートカット | アプリ |
|---|---|
| `Cmd+1` | Ghostty |
| `Cmd+2` | Google Chrome |
| `Cmd+3` | Visual Studio Code |
| `Cmd+4` | Slack |
| `Cmd+5` | Figma |

設定を変更したら、次のコマンドで再起動します。

```bash
skhd --restart-service
```
