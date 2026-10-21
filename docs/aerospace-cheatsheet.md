# AeroSpace チートシート

設定ファイルは `~/.dotfiles/aerospace/aerospace.toml` で管理し、`~/.config/aerospace/aerospace.toml` からシンボリックリンクしている。

## 基本操作

| キー | 動作 |
|---|---|
| `Ctrl + Command + H/J/K/L` | フローティング表示を除き、左・下・上・右のタイルへフォーカス |
| Ghostty で `Ctrl + H/J/K/L` | 左・下・上・右のタイルへフォーカス（端では反対側へ循環） |
| `Ctrl + F` | SketchyBarと外側の余白を残した全画面表示 |
| `Ctrl + Y/O` | 前・次のワークスペースへ移動（端では反対側へ循環） |
| `Ctrl + Shift + 1〜9` | 選択中のウィンドウを指定番号のワークスペースへ送る（表示は現在のワークスペースに留まる） |
| Ghostty の tmux 外で `Ctrl + U/I` | `Ctrl + Y/O` と同じ前・次のワークスペース移動（端で循環） |

Ghostty の `Ctrl + H/J/K/L` と `Ctrl + U/I` は Hammerspoon が選択中のウィンドウを判定して振り分ける。`Ctrl + H/J/K/L` はClaude CodeなどのTUIやtmux内でもAeroSpaceへ送る。tmux内の `Ctrl + U/I` は既存のセッション切り替えとして動作し、他のアプリには干渉しない。判定には `tmux/tmux.conf` の `set-titles-string` が付ける `[tmux] ` という接頭辞を使う。tmux の設定を再読み込みしてから利用する。

Raycastから最大化する場合は、標準の `Maximize` ではなく `Maximize with AeroSpace` を使う。AeroSpaceの外側余白を維持し、再実行すると元のサイズへ戻る。

SketchyBarの左側にはワークスペース1〜9を常時表示し、各ワークスペースにあるウィンドウをアプリアイコンで示す。現在のワークスペースはアクセントカラーで強調する。Aqua Voiceは一覧から除外する。ワークスペース移動やウィンドウの追加・終了はイベント発生時に反映される。

## macOS標準の全画面表示との違い

- `Ctrl + F`: AeroSpaceの全画面表示。外側の余白、角丸、影、枠を維持する。
- `Ctrl + Command + F`: macOS標準の全画面表示。別のSpaceへ移動し、画面端まで広がる。
- 緑ボタン: macOS標準の全画面表示またはタイル配置。

## コマンド

```bash
# 設定を検証する
aerospace reload-config --dry-run --no-gui --warnings-as-errors

# 設定を再読み込みする
aerospace reload-config --no-gui

# 読み込まれている設定ファイルを確認する
aerospace config --config-path

# ウィンドウとワークスペースを確認する
aerospace list-windows --all
aerospace list-workspaces --all

# 一時的にウィンドウ管理を停止・再開する
aerospace enable off
aerospace enable on
```

## 見た目の調整

`aerospace/aerospace.toml` の次の値を変更する。

```toml
gaps.inner.horizontal = 10
gaps.inner.vertical = 10
gaps.outer.left = 16
gaps.outer.bottom = 16
gaps.outer.top = 32
gaps.outer.right = 16
```

- `inner`: ウィンドウ同士の間隔。
- `outer`: ディスプレイ端とウィンドウの間隔。
- 上側はSketchyBarの高さとオフセットを確保するため32pxにする。
- 値を大きくすると角丸や背景が目立ち、小さくすると作業領域が広がる。
- 外側余白はタイル表示に適用される。フローティング表示でもSketchyBarは最前面に表示される。

通常ウィンドウは自動的にタイル表示され、同じワークスペースに追加すると利用可能な領域を分割する。Aqua VoiceとRaycastはオーバーレイとしてフローティング表示を維持する。

### dwindle風の自動分割

`scripts/aerospace-autotile.sh` が選択中のタイルのサイズを読み、次のウィンドウを追加するための分割方向を準備する。横幅が高さ以上なら左右、縦長なら上下に分割する。横長のモニターでは、2分割後も横幅に余裕があれば左右分割を続ける。

公式版AeroSpaceとmacOS標準の`osascript`・CoreGraphicsのみを使用する。Hammerspoonや常駐ポーリング処理、追加の画面収録権限は不要。起動時・フォーカス変更時・通常ウィンドウ検出時に実行し、浮動ウィンドウとAeroSpaceの全画面表示は対象外にする。macOSからサイズを取得できなかった場合は何も変更しない。

`split`が準備した単一ウィンドウのコンテナを保持するため、`enable-normalization-flatten-containers`を`false`にする。分割方向を実際の寸法で決めるため、`enable-normalization-opposite-orientation-for-nested-containers`も`false`にする。既存の配置は自動で組み直さず、次に開くウィンドウから適用する。サイズ変更だけでは再計算しないため、手動リサイズ後は一度別のウィンドウへ移って戻るか、補助スクリプトを実行する。

別のMacでもリポジトリを`~/.dotfiles`に配置し、通常どおり`./setup.sh`で設定をリンクすれば利用できる。Apple SiliconとIntelのHomebrewのパスを両方検索する。既存環境への反映・検証は以下で行う。

```sh
aerospace reload-config --dry-run --no-gui --warnings-as-errors
aerospace reload-config --no-gui
bash "$HOME/.dotfiles/scripts/aerospace-autotile.sh"
python3 "$HOME/.dotfiles/scripts/test-aerospace-autotile.py"
```

自動分割を無効にする場合は、`after-startup-command`・`on-focus-changed`・`on-window-detected`から補助スクリプトの呼び出しを削除し、上記2つの正規化設定を`true`に戻す。

アコーディオン表示への切り替えキーは設定しない。デフォルトは導入時から `tiles` で、以前の `Ctrl + Option + ,` は削除済み。起動時、ウィンドウ・ワークスペースのフォーカス変更時、新規ウィンドウの検出時に、対象ワークスペースのルートを `tiles` に戻す。これはAeroSpace本体のアコーディオン機能を無効化する設定ではなく、外部CLIから明示的に変更されたレイアウトを常時監視するものでもない。

AeroSpaceのフローティング表示は、全ワークスペースへの固定表示を意味しない。Aqua Voiceのバーはワークスペース変更時に追従スクリプトで移動する。バーの点滅・消失やSecure Inputの警告が発生した場合は、[Aqua Voice・AeroSpace トラブルシューティング](./aqua-voice-aerospace-troubleshooting.md)を参照する。

## Macを閉じた後のワークスペース維持

AeroSpace 0.21.3-Betaでは、蓋を閉じて復帰すると既存ウィンドウが再検出され、選択中のワークスペースに集まる現象が報告されている。[スリープ復帰時の再検出に関する報告](https://github.com/nikitabobko/AeroSpace/discussions/2264)。

`hammerspoon/aerospace_workspaces.lua`が2秒ごとにウィンドウID・アプリのプロセスID・所属ワークスペースを記録する。スリープ・画面消灯・ロック時には記録を凍結し、復帰・ロック解除後に1秒間隔で6回確認して元のワークスペースへ戻す。同じアプリの複数ウィンドウも個別に扱う。Aqua VoiceとRaycast、新規ウィンドウ、終了済みウィンドウ、別プロセスに再利用されたIDは復元対象外にする。

Hammerspoonの既存設定から自動起動する。CLI処理は非同期で直列実行し、応答が2秒以内に返らなければ中断する。アプリ単位のワークスペース固定は行わない。最後の記録からスリープまでの約2秒以内に行った移動は記録されない場合がある。復帰直後の確認中は、手動移動よりスリープ前の所属を優先する。Hammerspoon再起動前の記録や、すでに失われた配置は復元できない。タイルの分割構造や全画面状態は復元対象外。

```sh
# Hammerspoonの設定を再読み込みする
hs -A -c 'hs.timer.doAfter(0.1, hs.reload); return true'

# enabled=true・trackedWindowsが表示されることを確認する
hs -A -c 'return hs.inspect(aerospaceworkspaces.status())'

# 実際のウィンドウを動かさず、復元処理を検証する
hs -A -c 'return dofile(os.getenv("HOME") .. "/.dotfiles/scripts/test-aerospace-workspaces.lua")'
```

実機確認は、複数ワークスペースにウィンドウを分けて2秒以上待ち、蓋を閉じてから開き、ロック解除後に所属が維持されるかを確認する。一時停止はHammerspoonコンソールまたはCLIから`aerospaceworkspaces.stop()`を実行する。

## 関連ファイル

- AeroSpace: `aerospace/aerospace.toml`
- スリープ復帰時の所属維持: `hammerspoon/aerospace_workspaces.lua`
- Ghostty: `ghostty/config`
- JankyBorders: `borders/bordersrc`
- SketchyBar: `sketchybar/sketchybarrc`
