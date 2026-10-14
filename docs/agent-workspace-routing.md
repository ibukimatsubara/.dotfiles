# ローカルエージェントのウィンドウ配置

Ghostty上で直接起動した `codex`、`claude`、`dsh`、`deepseek`、`harness` の表示要求を、そのGhosttyウィンドウが現在所属するAeroSpace workspaceへ配置する。

## 使い方

新しいGhosttyウィンドウで通常どおりエージェントを起動する。既存のシェルは `source ~/.zshrc` 後にエージェントを起動し直す。既に動いているエージェントには後から環境変数を追加できない。

エージェントの子プロセスでは、通常の `open` と `code` が共通処理を通る。明示的には次のように使用できる。

```sh
agent-open /absolute/path/to/report.pdf
agent-open /absolute/path/to/report.odt
agent-open https://example.com
open -R /absolute/path/to/report.pdf
code /absolute/path/to/project
```

ブラウザの調査・自動操作は既存のagent-browser skillを使い、成果物をユーザーに表示する場合だけ `agent-open` を使う。

## 仕組み

- 起動時にフォーカスされているGhosttyのAeroSpace window IDとアプリPIDを環境変数で渡す。workspace番号は保存しない。
- エージェントのPATHにだけ `scripts/agent-bin` を追加する。通常のシェルの `open` / `code` は変更しない。
- 表示要求時と配置直前に、元ウィンドウの現在のworkspaceを問い合わせる。元ウィンドウを後から移動しても追従する。
- Chrome、Finder、VS Codeは新しいウィンドウを明示的に作る。他のアプリはmacOSの関連付けに従って開き、アプリIDと文書名が一致する新しいウィンドウだけを配置する。
- 複数エージェントの表示要求をロックで直列化する。既存ウィンドウや複数候補から任意のものを選んで移動しない。
- Aqua VoiceとRaycastは対象外。既存のfloating・追従設定には触れない。

## 制限と失敗時の動作

- 対象はmacOSのローカルGhosttyで対話的に起動するエージェント。tmux、SSH、非対話起動は対象外。起動時にGhosttyがフォーカスされていない場合も記録しない。
- ラッパーを迂回する `/usr/bin/open`、アプリのGUI操作、独自のbrowserツールから作られるウィンドウは自動配置されない。
- Office系を含む任意の関連付けアプリに対応するが、アプリが既存ウィンドウを再利用した場合や文書名をタイトルに出さない場合、確実な対象を特定できない。その場合は10秒後に警告と終了コード75を返し、既存ウィンドウを動かさない。
- 複数ファイルをまとめた `open`、`open --args` / `-W`、VS Codeの `--reuse-window` / `--wait` などは既存のCLI動作をそのまま通し、配置しない。基本はファイルごとに開く。
- 同じアプリ・同じ文書をユーザーが同時に手動で開いた場合、完全な識別は保証できない。特にURLはタイトルを事前に予測できないため、新しいChromeウィンドウが1つの場合だけ移動する。
- Chrome/Finder/VS Code側の自動アクティベートを完全には抑制できない。workspace切替コマンドは実行しないが、アプリ自身がフォーカスを取る場合がある。
- 元のGhosttyが閉じられた場合は、別のウィンドウを推測せず要求を失敗させる。エージェントを新しいウィンドウで起動し直す。
- Chrome/Finderの新規作成はAppleScriptを使うため、初回はmacOSのAutomation権限が必要になる場合がある。

## 確認

```sh
python3 scripts/test-agent-workspace-open.py
zsh -n zsh/functions/agent-workspace.zsh zsh/main.zsh
bash -n setup.sh
```

`deepseek` と `harness` はコマンドが存在する場合に有効。現在のDSHの別名 `dcode` は `dsh` ラッパーを経由する。
