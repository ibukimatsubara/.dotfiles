# skhd 設定

macOSのグローバルショートカットから、現在のAeroSpaceワークスペースにあるアプリを開く・フォーカスするためにskhdを使用します。

対象アプリのウィンドウが現在のワークスペースにあれば、そのウィンドウへフォーカスします。別のワークスペースにしかない場合は移動せず、現在のワークスペースに新しいウィンドウを開きます。

## インストール

```bash
brew install skhd
skhd --start-service
```

`setup.sh`は`skhdrc`を`~/.skhdrc`へリンクし、サービスを起動します。

## ショートカット

| ショートカット | 動作 |
|---|---|
| `Cmd+1` | Ghosttyを開く・フォーカスする |
| `Cmd+2` | Google Chromeを開く・フォーカスする |
| `Cmd+3` | Visual Studio Codeを開く・フォーカスする |

設定を変更したら、次のコマンドで再起動します。

```bash
skhd --restart-service
```
