# Kitty Terminal 設定ガイド

## 概要
Kitty は GPU アクセラレーション対応の高速なターミナルエミュレータです。

## 設定ファイルの場所
- メイン設定: `~/.config/kitty/kitty.conf`
- テーマ: `~/.config/kitty/kitty-themes/`

## セットアップ

### 1. テーマのインストール
```bash
# kitty-themes リポジトリをクローン
git clone https://github.com/dexpota/kitty-themes.git ~/.config/kitty/kitty-themes
```

### 2. テーマの適用
kitty.conf の最後に以下を追加：
```conf
# Theme
include ./kitty-themes/themes/Dracula.conf
```

## 基本設定

### フォント設定
```conf
font_family      JetBrainsMono Nerd Font
font_size        13.0
bold_font        auto
italic_font      auto
bold_italic_font auto
```

### 背景透過
```conf
background_opacity 0.95
```

### カラースキーム（手動設定の場合）
```conf
foreground       #f8f8f2
background       #282a36
cursor           #f8f8f2
```

## 人気のテーマ

- **Dracula** - パープル系のダークテーマ
- **Tokyo-Night** - ダークブルー系
- **Gruvbox_Dark** - 温かみのあるダークテーマ
- **Nord** - クールな北欧風テーマ
- **Solarized_Dark** - 定番のダークテーマ
- **Catppuccin** - パステル調のテーマ

## テーマの変更方法

1. 利用可能なテーマを確認：
```bash
ls ~/.config/kitty/kitty-themes/themes/
```

2. kitty.conf の include 行を編集：
```bash
nvim ~/.config/kitty/kitty.conf
# include ./kitty-themes/themes/好きなテーマ.conf に変更
```

3. 設定をリロード：
- `Ctrl+Shift+F5` を押す
- またはKittyを再起動

## ライト/ダークモードの切り替え

`scripts/kitty-theme-toggle.sh` で `theme.conf` を張り替えてライト/ダークを即切り替えできます。Kittyが起動中なら `SIGUSR1` を送り即リロードします。

```bash
# 現在のテーマを確認
~/.dotfiles/scripts/kitty-theme-toggle.sh status

# ライト（white）/ダークを直接指定
~/.dotfiles/scripts/kitty-theme-toggle.sh light
~/.dotfiles/scripts/kitty-theme-toggle.sh dark

# 引数なしでトグル
~/.dotfiles/scripts/kitty-theme-toggle.sh
```

- `setup.sh` 実行時はデフォルトでダークテーマにリンクされます。
- `theme.conf` が見つからない場合はスクリプトが自動で作成します。

## インタラクティブなテーマ選択

Kittyの組み込み機能でテーマをプレビューしながら選択：
```bash
kitten themes
```

## 便利なショートカット

- `Ctrl+Shift+F5` - 設定のリロード
- `Ctrl+Shift+F2` - 設定ファイルを開く
- `Ctrl+Shift+=` - フォントサイズを大きく
- `Ctrl+Shift+-` - フォントサイズを小さく
- `Ctrl+Shift+Backspace` - フォントサイズをリセット

## 背景画像設定

### Directory Structure
```
~/Pictures/kitty-wallpapers/
└── illust_130223414_20250808_055329.png  # 現在設定中の背景画像
```

### Configuration
```bash
# ~/.config/kitty/kitty.conf に追加された設定
background_image ~/Pictures/kitty-wallpapers/illust_130223414_20250808_055329.png
```

### Toggle Script
作成されたコマンド: `kitty-bg-toggle`

**場所**: `~/.local/bin/kitty-bg-toggle`

**機能**:
- 🎨 背景画像のオン/オフを1コマンドで切り替え
- ✅ Kitty実行中なら即座に反映 (SIGUSR1シグナル)
- ⚠️ Kitty未実行時は次回起動時に反映

**使用法**:
```bash
kitty-bg-toggle  # 背景画像の表示/非表示を切り替え
```

### Setup History
1. `~/Pictures/kitty-wallpapers/` フォルダを作成
2. 背景画像ファイルを配置
3. `~/.config/kitty/kitty.conf` に背景画像設定を追加
4. トグルスクリプト `kitty-bg-toggle` を作成 (`~/.local/bin/`)
5. スクリプトに実行権限を付与
6. `~/.zshrc` に `~/.local/bin` をPATHに追加

### Files Modified
- `~/.config/kitty/kitty.conf` - 背景画像設定追加
- `~/.local/bin/kitty-bg-toggle` - トグルスクリプト作成
- `~/.zshrc` - PATH環境変数にスクリプトディレクトリを追加

### Additional Notes
- 画像ファイルは PNG/JPG 形式対応
- 背景画像の透明度や表示方法は `kitty.conf` で調整可能
- 複数画像のローテーション機能は別途シェルスクリプトで実装可能

## 参考リンク

- [Kitty公式ドキュメント](https://sw.kovidgoyal.net/kitty/)
- [kitty-themes リポジトリ](https://github.com/dexpota/kitty-themes)
- [Catppuccin for Kitty](https://github.com/catppuccin/kitty)
