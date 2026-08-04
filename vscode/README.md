# VS Code

VS CodeはmacOSとUbuntuで同じ設定、キーバインド、拡張機能一覧を使います。

## キーバインド

- `Ctrl+h/j/k/l`: 左・下・上・右のエディタグループへ移動
- `Ctrl+u/i`: 同じグループ内の前・次のタブへ移動
- `Ctrl+Shift+h/j/k/l`: 現在のタブを隣のグループへ移動
- `Ctrl+Shift+u/i`: 現在のタブを左・右へ並べ替え

統合ターミナルにフォーカスがあるときは、VS Codeではなくシェルやtmuxへキーを渡します。

## 復元

`./setup.sh`は次のUserディレクトリへ`settings.json`と`keybindings.json`をリンクします。

- macOS: `~/Library/Application Support/Code/User/`
- Ubuntu: `~/.config/Code/User/`

`extensions.txt`の空行とコメントを除いた拡張機能もインストールします。拡張機能のバージョンは固定せず、復元時点の最新版を利用します。

VS Code Settings Syncは補助として利用できますが、このリポジトリを設定の正本とします。
