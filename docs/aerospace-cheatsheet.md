# AeroSpace チートシート

設定ファイルは `~/.dotfiles/aerospace/aerospace.toml` で管理し、`~/.config/aerospace/aerospace.toml` からシンボリックリンクしている。

## 基本操作

| キー | 動作 |
|---|---|
| `Ctrl + Option + H/J/K/L` | 左・下・上・右のウィンドウへフォーカス |
| `Ctrl + Option + Shift + H/J/K/L` | ウィンドウを左・下・上・右へ移動 |
| `Ctrl + Option + -` | ウィンドウを縮小 |
| `Ctrl + Option + =` | ウィンドウを拡大 |
| `Ctrl + Option + /` | タイルの分割方向を切り替え |
| `Ctrl + Option + ,` | タイル・アコーディオン表示を切り替え |
| `Ctrl + Option + F` | SketchyBarと外側の余白を残した全画面表示 |
| `Ctrl + Option + Shift + Space` | フローティング・タイル表示を切り替え |
| `Ctrl + Option + 1〜9` | ワークスペースを切り替え |
| `Ctrl + Option + Shift + 1〜9` | ウィンドウを指定ワークスペースへ移動 |
| `Ctrl + Option + Tab` | 現在と直前のワークスペースを往復 |

Raycastから最大化する場合は、標準の `Maximize` ではなく `Maximize with AeroSpace` を使う。AeroSpaceの外側余白を維持し、再実行すると元のサイズへ戻る。

## macOS標準の全画面表示との違い

- `Ctrl + Option + F`: AeroSpaceの全画面表示。外側の余白、角丸、影、枠を維持する。
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
- 上側はSketchyBarの高さとオフセットを確保するため48pxにする。
- 値を大きくすると角丸や背景が目立ち、小さくすると作業領域が広がる。
- 外側余白はタイル表示に適用される。フローティング表示ではウィンドウを自由に重ねられ、SketchyBarは最前面に表示される。

通常ウィンドウは `on-window-detected` ルールでフローティング表示にし、macOS標準と同じように重ねて配置できる。必要なウィンドウだけ並べたい場合は `Ctrl + Option + Shift + Space` でタイル表示に切り替える。

## 関連ファイル

- AeroSpace: `aerospace/aerospace.toml`
- Ghostty: `ghostty/config`
- JankyBorders: `borders/bordersrc`
- SketchyBar: `sketchybar/sketchybarrc`
