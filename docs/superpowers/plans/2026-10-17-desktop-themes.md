# Desktop Themes Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline execution.

**Goal:** Ghostty・SketchyBar・壁紙を保存済みテーマとして切り替える。

**Architecture:** JSON のプリセットを検証し、テーマごとの壁紙をキャッシュする。生成済み設定を atomic な `current` リンク経由で各アプリに読み込ませ、Hammerspoon で反映とキーボード選択を行う。

**Tech Stack:** Bash, Python 3 標準ライブラリ, Lua, Hammerspoon.

**Spec:** `docs/superpowers/specs/2026-10-17-desktop-themes-design.md`

## Global Constraints

- 既存のキー操作・コピー・タイマーの設定を維持する。
- 生成物と画像は Git に追加しない。
- テーマ未選択時は従来の見た目を使う。
- 壁紙の取得・検証失敗時は現在のテーマを維持する。
- 今回と無関係な作業中の変更を維持する。

## Review Focus

- 不正なテーマ名や値は有効化前に拒否する。
- テーマの循環は最後から最初に戻る。
- 画像の SHA-256 不一致や取得失敗で現在の生成物を壊さない。
- パスに空白がある環境でも shell 引数・Lua の文字列を正しく扱う。
- 起動時や画面変更時も選択中のテーマ内の壁紙を適用する。

### Task 1: CLI and presets

**Files:** `scripts/desktop-theme.sh`, `scripts/desktop-theme.py`, `scripts/test-desktop-theme.py`, `desktop-themes/*/theme.json`.

**Interfaces:** `current/theme.json` は `name`, `label`, `rotation_seconds`, `wallpapers`（`id`, `path`）を提供する。同じ生成先に `ghostty.conf`, `sketchybar-colors.sh`, `sketchybar-style.sh` を提供する。

- [x] 一時 HOME で CLI の失敗・生成・循環を検証するテストを書く。
- [x] 未実装で失敗することを確認する。
- [x] 検証、キャッシュ、生成、atomic 有効化、CLI を実装する。
- [x] Python テストを実行する。

### Task 2: App integration and keyboard controls

**Files:** `ghostty/config`, `sketchybar/colors.sh`, `sketchybar/sketchybarrc`, `hammerspoon/wallpaper.lua`, `hammerspoon/desktop_theme.lua`, `hammerspoon/init.lua`, `zsh/configs/desktop-theme.zsh`, `scripts/test-wallpaper.lua`.

**Interfaces:** Task 1 の `current` 配下を読み、`desktoptheme.refresh()` がアプリの再読込とテーマ内壁紙の適用を行う。

- [x] テーマ内の壁紙選択と旧画面別選択の Lua テストを書き、変更前の失敗を確認する。
- [x] Ghostty・バーの include、壁紙切替、chooser とホットキーを実装する。
- [x] Lua・Python テスト、シェル・Lua 構文検証を実行する。
- [x] 実機に反映し、両プリセットを往復して既存タイマーが維持されることを確認する。
- [x] 操作・追加方法・出典を `docs/desktop-themes.md` にまとめる。

### Task 3: Attached bar sections and display frame

**Files:** `hammerspoon/bar_corners.lua`, `scripts/desktop-theme.py`, `desktop-themes/anime-blue/theme.json`, `sketchybar/sketchybarrc`, `sketchybar/plugins/now_playing.sh`, `docs/desktop-themes.md`.

- [x] 左・中央・右を分離し、上端と画面端に逆角丸でつなげる。
- [x] 再生情報とワークスペースの幅の変化に追従する画像を生成する。
- [x] 左端の丸アイコンを非表示にする。
- [x] 下の逆角丸と 4pt の画面枠を追加し、マウス操作を通過させる。
- [x] 実機で描画位置、画面構成への追従、タイマーの維持を確認する。

## Verification record

- Python: 9 tests passed。通信失敗、SHA-256 不一致、重複 ID、生成設定の shell 読み込み、テーマの循環を含む。
- Lua: wallpaper、break-timer、Ghostty navigation のテストが成功。
- Ghostty `+validate-config`、Bash/Zsh/Lua 構文検証、`git diff --check` が成功。
- 新規の一時 HOME から両プリセットの全画像を実際に取得し、ハッシュ検証と設定生成が成功。
- 実機で両テーマを適用し、Ghostty の実効設定、SketchyBar の色・角丸、壁紙 URL、chooser、キー登録、既存タイマーオブジェクトの維持を確認。
- 最終の `anime-blue` で、4pt の枠と逆角丸の 8 キャンバスが表示され、マウスイベントを受け取らないことを実機で確認。バーは余白 0・高さ 40pt・3 ブロックを維持。
- 独立した読み取り専用レビューで修正を要する指摘なし。
- Ruling: Pexels が Python の既定 User-Agent を 403 で拒否したため、識別可能なクライアント名を送信する。既存キャッシュなしの実機試験で再確認済み。
