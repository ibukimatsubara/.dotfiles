# AeroSpace チートシート

設定ファイルは `~/.dotfiles/aerospace/aerospace.toml` で管理し、`~/.config/aerospace/aerospace.toml` からシンボリックリンクしている。

## 基本操作

| キー | 動作 |
|---|---|
| `Ctrl + Command + H/J/K/L` | フローティング表示を除き、左・下・上・右のタイルへフォーカス |
| `Ctrl + Option + ,` | タイル・アコーディオン表示を切り替え |
| `Ctrl + F` | SketchyBarと外側の余白を残した全画面表示 |
| `Ctrl + Y/O` | 前・次のワークスペースへ移動（端では反対側へ循環） |

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

AeroSpaceのフローティング表示は、全ワークスペースへの固定表示を意味しない。Aqua Voiceのバーはワークスペース変更時に追従スクリプトで移動する。バーの点滅・消失やSecure Inputの警告が発生した場合は、[Aqua Voice・AeroSpace トラブルシューティング](./aqua-voice-aerospace-troubleshooting.md)を参照する。

## 関連ファイル

- AeroSpace: `aerospace/aerospace.toml`
- Ghostty: `ghostty/config`
- JankyBorders: `borders/bordersrc`
- SketchyBar: `sketchybar/sketchybarrc`
