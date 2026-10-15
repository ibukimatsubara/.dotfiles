# Aqua Voice・AeroSpace トラブルシューティング

Aqua Voiceのフローティングバーが点滅・消失したり、音声入力のショートカットが反応しなくなった場合の切り分けメモ。

## 今回の原因

問題は1つではなく、次の3つが重なっていた。

| 症状 | 原因 | 対応 |
|---|---|---|
| ワークスペースを切り替えるとバーが点滅・消失する | AeroSpaceでは、フローティングウィンドウも特定のワークスペースに所属する | ワークスペース変更時にAqua Voiceのウィンドウを現在のワークスペースへ移動する |
| バーは出るが、ガラス表示が不安定に見える | Aqua VoiceのLiquid Glass版フローターと現在のウィンドウ構成の相性 | フローティングバーは有効のまま、Liquid Glassだけ無効にする |
| Aqua VoiceやAeroSpaceのショートカットが反応せず、AeroSpaceの盾アイコンが出る | macOSのSecure Inputにより、グローバルなキー監視が遮断されていた | GhosttyによるSecure Inputの自動有効化を止め、発生元を終了・再起動する |

### `floating` は `sticky` ではない

AeroSpaceは非アクティブなワークスペースのウィンドウを画面外へ移動して、ワークスペースを再現している。Aqua Voiceのバーは常に手前へ表示されるウィンドウだが、`layout floating` にしてもワークスペースへの所属は残る。

そのため、Aqua Voiceを起動したワークスペースから移動すると、バーも元のワークスペースと一緒に画面外へ移動していた。フローティング指定はタイル配置から外すためのもので、全ワークスペースに固定表示する指定ではない。

現在は `scripts/aerospace-workspace-changed.sh` がSketchyBarの選択表示だけを即時更新し、Aqua Voiceの移動は非同期workerへ渡す。連続したワークスペース変更は1つのworkerへまとめ、途中の状態を順番に処理せず、最後にフォーカスされたワークスペースへ収束させる。

SketchyBarからの定期的なAeroSpace照会も、フローティングウィンドウが変化するタイミングと競合する機会を増やしていた可能性がある。これは主原因とは断定できないが、点滅を増幅する要因を減らすため、現在はウィンドウ変更イベントでのみ更新している。

### Secure Inputは別の問題

Secure Inputは、パスワード入力中などに他のアプリがキーボードイベントを読めないようにするmacOSの保護機能。これが有効な間は、Aqua VoiceやAeroSpaceのようなグローバルショートカットもキーを受け取れない。

AeroSpaceの右下に出る盾アイコンは原因ではなく、Secure Inputが有効でショートカットを処理できないことを知らせる警告。Ghosttyでは自動判定による有効化を止めているが、パスワード欄や他のアプリがSecure Inputを有効にすることはある。

## 現在の対策

- `aqua-voice/settings.json`: クラシック版フローティングバーを有効にする安全な設定だけを管理する。
- `scripts/apply-aqua-voice-settings.sh`: Aqua Voiceの実設定へ管理対象のキーだけをマージする。
- `aerospace/aerospace.toml`: Aqua Voiceをフローティング表示にし、ワークスペース変更スクリプトを呼ぶ。
- `scripts/aerospace-workspace-changed.sh`: SketchyBarを即時更新し、非同期workerでAqua Voiceを現在のワークスペースへ追従させる。
- `sketchybar/sketchybarrc`: ワークスペース状態を定期監視せず、ウィンドウ変更イベントでアプリアイコンを更新する。
- `ghostty/config`: `macos-auto-secure-input = false` にして、自動的なSecure Inputの有効化を防ぐ。

Aqua Voiceの実設定ファイルにはトークンなどの端末固有情報が入っているため、実ファイル全体はシンボリックリンクせず、Gitにも含めない。

## 症状別の確認方法

### バーが消える・ワークスペース変更時に点滅する

フォーカス中のワークスペースと、Aqua Voiceが所属するワークスペースを比較する。

```bash
focused_workspace="$(aerospace list-workspaces --focused)"
aqua_workspace="$(
  aerospace list-windows --all --format '%{workspace}|%{app-bundle-id}' |
    awk -F'|' '$2 == "com.electron.aqua-voice" { print $1; exit }'
)"
printf 'focused=%s aqua=%s\n' "$focused_workspace" "$aqua_workspace"
```

両者が異なる場合は、追従スクリプトを手動実行する。

```bash
~/.dotfiles/scripts/aerospace-workspace-changed.sh \
  "$(aerospace list-workspaces --focused)"
```

Aqua Voiceのウィンドウ一覧とレイアウトも確認できる。

```bash
aerospace list-windows --all \
  --format '%{window-id}|%{workspace}|%{app-bundle-id}|%{window-layout}' |
  rg 'com\.electron\.aqua-voice'
```

画面外へ移動している疑いがある場合は、対象ウィンドウの座標を確認する。`debug-windows` はAeroSpaceのデバッグ用コマンドのため、将来書式が変わる可能性がある。

```bash
aqua_window_id="$(
  aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}' |
    awk -F'|' '$2 == "com.electron.aqua-voice" { print $1; exit }'
)"
aerospace debug-windows --window-id "$aqua_window_id" |
  rg 'AXFrame|Aero.windowLevel|Aero.workspace|Aero.treeNodeParent'
```

### バーの見た目が変わった・設定が戻った

現在のAqua Voice設定を確認する。

```bash
jq '{showFloatingBar, glassFloaterEnabled}' \
  "$HOME/Library/Application Support/Aqua Voice/settings.json"
```

期待値は次のとおり。

```json
{
  "showFloatingBar": true,
  "glassFloaterEnabled": false
}
```

Aqua Voiceの更新などで戻った場合は、アプリを完全に終了してから設定を再適用する。

```bash
~/.dotfiles/scripts/apply-aqua-voice-settings.sh
```

### ショートカットが反応せず、盾アイコンが出る

Secure Inputの状態を確認する。

```bash
osascript -l JavaScript \
  -e 'ObjC.import("Carbon"); console.log($.IsSecureEventInputEnabled())'
```

`false` なら無効、`true` なら有効。`true` の場合は次を順番に試す。

1. パスワード入力欄からフォーカスを外す。
2. 直前にパスワード入力をしたアプリを終了する。
3. Ghosttyをウィンドウだけでなくアプリごと完全に終了して、再起動する。
4. 改善しなければ画面をロックして再ログインする。

Secure Input自体はmacOSの安全機能なので、システム全体で恒久的に無効化するのではなく、有効にしたアプリを特定して解除する。

### GhosttyのCtrl+H/LでCodex CLIに「disabled」と表示される

2026-10-14、GhosttyでCodex CLIのタスク実行中に次の表示が出た。

```text
Ctrl+L is disabled while a task is in progress.
```

これはCodex CLI自身のメッセージ。Ctrl+Lに割り当てられたCodex側の操作が、タスク実行中のため拒否されたことを示す。Ghosttyのtmux外では、本来 `hammerspoon/ghostty_navigation.lua` がこのキーを消費してAeroSpaceのフォーカス移動を実行する。表示が出た時点では、キーがCodexまで届いていた。

調査中にユーザーの再操作で正常な移動へ復旧した。復旧までに常設の設定・コード変更はしていない。最初にキーを取り逃がした理由は、発生時の入力記録がないため未確定。Secure Inputやタスク実行中の負荷を原因と断定しない。

追加確認では、この端末のHammerspoonのログイン時自動起動が `false` で、`setup.sh` にもHammerspoonの起動処理がなかった。これは別のMacや次のログインで起動漏れを起こし得る不足だが、今回の取り逃がしの原因だったとは確認していない。

その後、別のMacで復元する際の起動不足を防ぐため、`setup.sh` でHammerspoonを起動し、`hammerspoon/init.lua` でログイン時自動起動を有効にした。初回キー入力中に拡張をロードしないよう、ナビゲーション処理が使う拡張も起動時に読み込む。[別のMacでの復元手順](./setup.md#ghosttyのキー操作を別のmacで復元する)と、今回の未確定の発生原因を区別する。

確認できた状態:

- Hammerspoonのキー監視は `enabled = true`、振り分け先は `route = "aerospace"`。
- 調査時のSecure Inputは `false`。
- 復旧後の実際のCtrl+L/Hは `ctrl = true` のみで、tmux外の通常のGhosttyウィンドウから入力されていた。
- Hammerspoonコンソールに、この監視処理のエラーは見つからなかった。
- 切り分けに使った一時的な入力監視は、調査後に停止した。常設の入力ログは残さない。

再発したら、監視を再起動する前に次の状態を記録する。

```bash
hs -A -t 3 -c 'return hs.inspect({navigation=ghosttynavigation and ghosttynavigation.status(),secureInput=hs.eventtap.isSecureInputEnabled()})' </dev/null
```

tmux外のGhosttyで `enabled = true`、`route = "aerospace"`、`secureInput = false` が期待値。tmux内でも方向キーは `route = "aerospace"` が期待値。`workspaceRoute = "tmux"` なら `Ctrl+U/I` だけtmuxのセッション操作へ通す。`route = "passthrough"` なら、前面アプリ、選択中のウィンドウ、入力欄のフォーカスを確認する。Secure Inputが `true` なら、上の「ショートカットが反応せず、盾アイコンが出る」の手順で発生元を確認する。

状態を保存した後、キー監視だけを停止・再開して再操作する。タイマーや作業中のCodexを終了する必要はない。

```bash
hs -A -t 3 -c 'assert(ghosttynavigation,"Ghostty navigation is not loaded"); ghosttynavigation.tap:stop(); ghosttynavigation.tap:start(); return hs.inspect(ghosttynavigation.status())' </dev/null
```

この操作にはHammerspoonの [`hs.eventtap:stop()/start()`](https://www.hammerspoon.org/docs/hs.eventtap.html) を使う。監視再起動は再発時に試す復帰手順であり、今回の原因が特定できたことを意味しない。

## 設定を変更した後の再読み込み

```bash
aerospace reload-config --no-gui
brew services restart sketchybar
```

Ghosttyの `macos-auto-secure-input` は、設定リロードではなくアプリの完全再起動後に確認する。

## 動作確認

- Aqua Voiceが待機中でもクラシックなピル型バーを表示する。
- 音声入力を開始すると、バーに波形と操作ボタンが表示される。
- ワークスペースを何度か素早く切り替えても、バーが現在のワークスペースに残る。
- 上記コマンドで `focused` と `aqua` が一致する。
- Secure Inputの確認結果が `false` で、Aqua VoiceとAeroSpaceのショートカットが反応する。
- SketchyBarのワークスペース項目がイベント駆動になっている。

```bash
sketchybar --query workspace.1 | jq '.scripting | {update_freq, updates}'
```

`update_freq` が `0` なら、定期ポーリングは無効になっている。
