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

## 参考リンク

- [Kitty公式ドキュメント](https://sw.kovidgoyal.net/kitty/)
- [kitty-themes リポジトリ](https://github.com/dexpota/kitty-themes)
- [Catppuccin for Kitty](https://github.com/catppuccin/kitty)