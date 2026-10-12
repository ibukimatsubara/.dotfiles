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

現在は `scripts/aerospace-workspace-changed.sh` がワークスペース変更のたびにAqua Voiceの全ウィンドウを現在のワークスペースへ移動する。短時間に連続して切り替えた場合も、最後にフォーカスされたワークスペースを再確認して追従する。

SketchyBarからの定期的なAeroSpace照会も、フローティングウィンドウが変化するタイミングと競合する機会を増やしていた可能性がある。これは主原因とは断定できないが、点滅を増幅する要因を減らすため、現在はウィンドウ変更イベントでのみ更新している。

### Secure Inputは別の問題

Secure Inputは、パスワード入力中などに他のアプリがキーボードイベントを読めないようにするmacOSの保護機能。これが有効な間は、Aqua VoiceやAeroSpaceのようなグローバルショートカットもキーを受け取れない。

AeroSpaceの右下に出る盾アイコンは原因ではなく、Secure Inputが有効でショートカットを処理できないことを知らせる警告。Ghosttyでは自動判定による有効化を止めているが、パスワード欄や他のアプリがSecure Inputを有効にすることはある。

## 現在の対策

- `aqua-voice/settings.json`: クラシック版フローティングバーを有効にする安全な設定だけを管理する。
- `scripts/apply-aqua-voice-settings.sh`: Aqua Voiceの実設定へ管理対象のキーだけをマージする。
- `aerospace/aerospace.toml`: Aqua Voiceをフローティング表示にし、ワークスペース変更スクリプトを呼ぶ。
- `scripts/aerospace-workspace-changed.sh`: Aqua Voiceを現在のワークスペースへ追従させる。
- `sketchybar/sketchybarrc`: ワークスペース状態を定期監視せず、イベント発生時に更新する。
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
