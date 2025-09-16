# yabai & skhd 設定ガイド

## 概要

このドキュメントでは、macOSのタイル型ウィンドウマネージャー「yabai」とホットキーデーモン「skhd」の設定について説明します。

## インストール

### 必要なツールのインストール

```bash
# yabaiのインストール
brew install koekeishiya/formulae/yabai

# skhdのインストール
brew install koekeishiya/formulae/skhd
```

### SIPの部分的な無効化（スペース切り替えに必要）

**スペース切り替え機能**を使用するには、System Integrity Protection (SIP)の部分的な無効化が必要です。

### 詳細な手順
詳しいSIP設定方法は **[docs/sip-setup.md](./sip-setup.md)** を参照してください。

### 簡単な手順
1. macOSをリカバリーモードで起動
   - **Apple Silicon**: 電源ボタン長押し → 「オプション」選択
   - **Intel**: 起動時に`⌘ + R`
2. ターミナルで実行: `csrutil enable --without fs --without debug --without nvram`
3. 再起動後に実行: `sudo yabai --load-sa`

## 設定ファイル

### yabairc

`~/.dotfiles/yabairc` - ウィンドウマネージャーの設定

主な設定内容：
- ウィンドウの自動配置（BSPレイアウト）
- ウィンドウ間のギャップ設定
- 特定アプリケーションの除外ルール
- スペース（仮想デスクトップ）の設定

### skhdrc

`~/.dotfiles/skhdrc` - キーボードショートカットの設定

## キーボードショートカット

### ウィンドウナビゲーション

| ショートカット | 動作 |
|--------------|------|
| `alt + h/j/k/l` | 左/下/上/右のウィンドウへフォーカス |
| `cmd + j/k` | 前/次のウィンドウへフォーカス |

### ウィンドウ移動

| ショートカット | 動作 |
|--------------|------|
| `shift + alt + h/j/k/l` | ウィンドウを左/下/上/右と入れ替え |
| `shift + cmd + h/j/k/l` | ウィンドウを左/下/上/右へワープ |
| `shift + alt + 1-9,0` | ウィンドウをスペース1-10へ移動 |
| `shift + alt + p/n` | ウィンドウを前/次のスペースへ移動 |

### ウィンドウサイズ変更

| ショートカット | 動作 |
|--------------|------|
| `ctrl + alt + h/j/k/l` | ウィンドウサイズを調整 |
| `ctrl + alt + e` | ウィンドウサイズを均等化 |

### ウィンドウ操作

| ショートカット | 動作 |
|--------------|------|
| `shift + alt + space` | フローティングウィンドウの切り替え |
| `alt + f` | フルスクリーンの切り替え |
| `alt + d` | 親ズームの切り替え |
| `alt + e` | 分割タイプの切り替え |
| `alt + s` | スティッキー（全スペース表示）の切り替え |
| `alt + o` | 最前面表示の切り替え |
| `alt + p` | ピクチャーインピクチャーの切り替え |

### スペース（仮想デスクトップ）操作

**⚠️ スペース切り替えにはSIP部分無効化が必要**

| ショートカット | 動作 |
|--------------|------|
| `ctrl + 1-4` | スペース1-4へ移動（SIP無効化後） |
| `shift + ctrl + 1-4` | ウィンドウをスペース1-4へ移動 |

**SIP無効化前でも使える機能:**
- ウィンドウのスペース間移動
- macOS標準のMission Control（`ctrl + ←/→`）

### レイアウト管理

| ショートカット | 動作 |
|--------------|------|
| `ctrl + alt + a` | BSPレイアウトに変更 |
| `ctrl + alt + d` | フロートレイアウトに変更 |
| `ctrl + alt + s` | スタックレイアウトに変更 |
| `alt + r` | ツリーを90度回転 |
| `alt + y/x` | Y軸/X軸でミラー |

### アプリケーション起動

| ショートカット | 動作 |
|--------------|------|
| `cmd + return` | Kittyターミナルを開く |
| `cmd + shift + return` | iTermを開く |
| `alt + return` | Alacrittyを開く |
| `cmd + shift + f` | Finderを開く |
| `cmd + shift + s` | Safariを開く |
| `cmd + shift + c` | Google Chromeを開く |
| `cmd + shift + v` | VS Codeを開く |

### yabai管理

| ショートカット | 動作 |
|--------------|------|
| `ctrl + alt + cmd + r` | yabaiを再起動 |
| `ctrl + alt + cmd + q` | yabaiを停止 |

## サービスの起動

```bash
# yabaiの起動
yabai --start-service

# skhdの起動
skhd --start-service

# 自動起動の設定
brew services start yabai
brew services start skhd
```

## トラブルシューティング

### yabaiが動作しない場合

1. SIPの設定を確認
2. アクセシビリティ権限を確認（システム設定 → プライバシーとセキュリティ）
3. ログを確認: `tail -f /tmp/yabai_*.err.log`

### skhdが動作しない場合

1. アクセシビリティ権限を確認
2. 設定ファイルの構文エラーを確認: `skhd -c ~/.config/skhd/skhdrc`
3. 既存のホットキーとの競合を確認

## カスタマイズ

設定ファイルを編集後、以下のコマンドで再読み込み：

```bash
# yabaiの再読み込み
yabai --restart-service

# skhdの再読み込み
skhd --restart-service
```

## 参考リンク

- [yabai公式ドキュメント](https://github.com/koekeishiya/yabai)
- [skhd公式ドキュメント](https://github.com/koekeishiya/skhd)
- [yabai Wiki](https://github.com/koekeishiya/yabai/wiki)