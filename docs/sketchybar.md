# SketchyBar 設定ガイド

## 概要
SketchyBarは、macOSのメニューバーを完全にカスタマイズできる高機能なステータスバーです。スクリプトベースで動的に設定を変更でき、アニメーション、グラフ、インタラクティブな要素をサポートしています。

このdotfilesでは、ミニマルで美しいカスタム設定を提供しています。

## インストール

### 1. Homebrewでインストール
```bash
brew tap FelixKratz/formulae
brew install sketchybar
```

### 2. サービスの開始
```bash
# 自動起動を有効にして開始
brew services start felixkratz/formulae/sketchybar

# または手動で起動
sketchybar
```

## 設定ファイルの構成

### ディレクトリ構造
```
~/.dotfiles/sketchybar/
├── sketchybarrc        # メイン設定ファイル
├── colors.sh           # カラースキーム定義
├── icons.sh            # アイコン定義
├── globalstyles.sh     # グローバルスタイル設定
├── items/              # バーアイテムの設定
│   ├── spaces.sh       # ワークスペース表示
│   ├── datetime.sh     # 日時表示
│   ├── battery.sh      # バッテリー情報
│   ├── wifi.sh         # WiFi状態
│   ├── volume.sh       # 音量表示
│   ├── weather.sh      # 天気情報
│   └── ...            # その他のアイテム
└── plugins/            # 動的更新用スクリプト
    ├── battery.sh      # バッテリー更新
    ├── wifi.sh         # WiFi情報更新
    ├── weather.sh      # 天気情報取得
    └── ...            # その他のプラグイン
```

### シンボリックリンクの作成
```bash
# dotfilesからconfig directoryへのリンク
ln -sf ~/.dotfiles/sketchybar ~/.config/sketchybar
```

## 現在の設定内容（カスタムミニマル）

### レイアウト
**右側のみの表示（左から右へ）:**
1. **🔔 通知ベル** - notifications_bell
2. **🌙 フォーカストグル** - focus_toggle  
3. **🔋 バッテリー** - battery
4. **🕐 時刻・日付** - clock/date

### 各アイテムの機能

#### 通知ベル (notifications_bell)
- **通知なし:** 白いベル (󰂚)
- **通知あり:** 赤いベル (󰅸) + 赤い背景
- **クリック:** 通知センターを開く

#### フォーカストグル (focus_toggle)
- **フォーカスOFF:** グレーの月 (󰂛) + グレー背景
- **フォーカスON:** 紫の月 (󰂛) + 紫背景
- **クリック:** フォーカスモード（おやすみモード）のトグル
- **通知:** 切り替え時にシステム通知表示

#### バッテリー (battery)
- **70%以上:** 緑色フルバッテリーアイコン (󰁹)
- **40-70%:** 黄色ハーフバッテリーアイコン (󰂀)
- **20-40%:** オレンジ低バッテリーアイコン (󰁻)
- **20%未満:** 赤色低バッテリーアイコン (󰁺)
- **充電中:** 緑色充電アイコン (󰂄)
- **パーセンテージ表示**
- **クリック:** バッテリー設定を開く

#### 時刻・日付 (datetime_custom)
- **時刻:** HH:MM形式、セミボールドフォント
- **日付:** M月D日(曜日)形式
- **クリック:** カレンダーアプリを開く

### デザインテーマ
モダンミニマル設計：
- **バー背景:** ダーク半透明 (0x22000000) + シャドウ
- **フォント:** SF Pro Display + JetBrainsMono Nerd Font
- **アイテム背景:** 角丸6px、半透明カラー
- **高さ:** 34px、適度なパディング

## カスタマイズ

### 色の変更
`~/.dotfiles/sketchybar/colors.sh`を編集：
```bash
# 例：背景色を変更
export BACKGROUND_COLOR=0xff1e1e1e
export TEXT_COLOR=0xffffffff
```

### アイコンの変更
`~/.dotfiles/sketchybar/icons.sh`を編集：
```bash
# 例：バッテリーアイコンを変更
export BATTERY_ICON="🔋"
```

### アイテムの追加/削除
`~/.dotfiles/sketchybar/sketchybarrc`を編集：
```bash
# アイテムを追加
source "$ITEM_DIR/custom_item.sh"

# アイテムを無効化（コメントアウト）
# source "$ITEM_DIR/weather.sh"
```

### 新しいアイテムの作成
1. `items/`ディレクトリに新しいシェルスクリプトを作成
2. `sketchybarrc`でそのスクリプトをsource
3. 必要に応じて`plugins/`に更新スクリプトを作成

## よく使うコマンド

```bash
# 設定をリロード
sketchybar --reload

# 現在の設定を確認
sketchybar --query bar

# 特定のアイテムの状態を確認
sketchybar --query <item_name>

# すべてのアイテムをリスト表示
sketchybar --query default_item

# SketchyBarを終了
brew services stop felixkratz/formulae/sketchybar

# ログを確認
tail -f /tmp/sketchybar.log
```

## トラブルシューティング

### SketchyBarが表示されない
```bash
# プロセスを確認
ps aux | grep sketchybar

# 手動で起動してエラーを確認
sketchybar

# 設定ファイルのパーミッションを確認
chmod +x ~/.config/sketchybar/plugins/*.sh
chmod +x ~/.config/sketchybar/items/*.sh
```

### アイテムが更新されない
- プラグインスクリプトの実行権限を確認
- `sketchybar --reload`で再読み込み
- ログファイルでエラーを確認

### システムの許可設定
初回起動時にmacOSのアクセシビリティ許可が必要な場合があります：
1. システム設定 → プライバシーとセキュリティ
2. アクセシビリティ → SketchyBarを許可

## 依存関係

必要なフォント（setup.shで自動インストール）：
- **JetBrainsMono Nerd Font**: アイコン表示用
- **SF Pro Display**: テキスト表示用（macOS標準）

オプション機能：
- **Shortcuts.app**: フォーカスモード切り替え（macOS標準）

## 参考リンク

- [SketchyBar公式ドキュメント](https://felixkratz.github.io/SketchyBar/)
- [Pe8er's dotfiles](https://github.com/Pe8er/dotfiles)
- [SketchyBar設定例集](https://github.com/FelixKratz/SketchyBar/discussions/47)

## アンインストール

```bash
# サービスを停止
brew services stop felixkratz/formulae/sketchybar

# アンインストール
brew uninstall sketchybar

# 設定ファイルを削除（オプション）
rm -rf ~/.config/sketchybar
```