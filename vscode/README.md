# VS Code

VS Codeは基本設定、キーバインド、拡張機能一覧を共有し、OS固有の設定だけを分けます。

## キーバインド

- `Ctrl+h/j/k/l`: 左・下・上・右のエディタグループへ移動
- `Ctrl+u/i`: 同じグループ内の前・次のタブへ移動
- `Ctrl+Shift+h/j/k/l`: 現在のタブを隣のグループへ移動
- `Ctrl+Shift+u/i`: 現在のタブを左・右へ並べ替え

統合ターミナルにフォーカスがあるときは、VS Codeではなくシェルやtmuxへキーを渡します。

## 復元

`./setup.sh` は `vscode/settings.json` と `platforms/<OS>/vscode-settings.json` を `jq` で再帰的にマージします。同じキーはOS別設定を優先します。生成先は `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/vscode/<OS>/settings.json` です。

次のUserディレクトリへ、生成した `settings.json` と共通の `keybindings.json` をリンクします。既存のファイル・旧リンクはバックアップします。

- macOS: `~/Library/Application Support/Code/User/`
- Ubuntu: `${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/`

`extensions.txt`の空行とコメントを除いた拡張機能もインストールします。拡張機能のバージョンは固定せず、復元時点の最新版を利用します。

VS Code Settings Syncは補助として利用できますが、このリポジトリを設定の正本とします。

共通の変更は `vscode/settings.json`、UbuntuのZshプロファイルなどは `platforms/ubuntu/vscode-settings.json` を編集し、`./setup.sh` を再実行してください。生成されたUser設定を直接編集すると、次のセットアップで上書きされます。
