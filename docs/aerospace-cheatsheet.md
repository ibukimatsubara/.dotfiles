# AeroSpace チートシート

設定ファイルは `~/.dotfiles/aerospace/aerospace.toml` で管理し、`~/.config/aerospace/aerospace.toml` からシンボリックリンクしている。

## 基本操作

| キー | 動作 |
|---|---|
| `Ctrl + Command + H/J/K/L` | フローティング表示を除き、左・下・上・右のタイルへフォーカス |
| Ghostty の tmux 外で `Ctrl + H/J/K/L` | 左・下・上・右のタイルへフォーカス（端では反対側へ循環） |
| `Ctrl + F` | SketchyBarと外側の余白を残した全画面表示 |
| `Ctrl + Y/O` | 前・次のワークスペースへ移動（端では反対側へ循環） |
| Ghostty の tmux 外で `Ctrl + U/I` | `Ctrl + Y/O` と同じ前・次のワークスペース移動（端で循環） |

Ghostty の `Ctrl + H/J/K/L` と `Ctrl + U/I` は Hammerspoon が選択中のウィンドウを判定して振り分ける。tmux に入っている場合は既存のペイン移動・セッション切り替えとして動作し、他のアプリには干渉しない。判定には `tmux/tmux.conf` の `set-titles-string` が付ける `[tmux] ` という接頭辞を使う。tmux の設定を再読み込みしてから利用する。

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
gaps.outer.top = 48
gaps.outer.right = 16
```

- `inner`: ウィンドウ同士の間隔。
- `outer`: ディスプレイ端とウィンドウの間隔。
- 上側はSketchyBarの高さとオフセットを確保するため52pxにする。
- 値を大きくすると角丸や背景が目立ち、小さくすると作業領域が広がる。
- 外側余白はタイル表示に適用される。フローティング表示でもSketchyBarは最前面に表示される。

通常ウィンドウは自動的にタイル表示され、同じワークスペースに追加すると利用可能な領域を分割する。Aqua VoiceとRaycastはオーバーレイとしてフローティング表示を維持する。

アコーディオン表示への切り替えキーは設定しない。デフォルトは導入時から `tiles` で、以前の `Ctrl + Option + ,` は削除済み。起動時、ウィンドウ・ワークスペースのフォーカス変更時、新規ウィンドウの検出時に、対象ワークスペースのルートを `tiles` に戻す。これはAeroSpace本体のアコーディオン機能を無効化する設定ではなく、外部CLIから明示的に変更されたレイアウトを常時監視するものでもない。

AeroSpaceのフローティング表示は、全ワークスペースへの固定表示を意味しない。Aqua Voiceのバーはワークスペース変更時に追従スクリプトで移動する。バーの点滅・消失やSecure Inputの警告が発生した場合は、[Aqua Voice・AeroSpace トラブルシューティング](./aqua-voice-aerospace-troubleshooting.md)を参照する。

## 関連ファイル

- AeroSpace: `aerospace/aerospace.toml`
- Ghostty: `ghostty/config`
- JankyBorders: `borders/bordersrc`
- SketchyBar: `sketchybar/sketchybarrc`
