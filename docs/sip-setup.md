# SIP（System Integrity Protection）設定ガイド

## 概要

yabaiでスペース切り替えなどの高度な機能を使用するには、macOSのSIP（System Integrity Protection）を部分的に無効化する必要があります。

## SIPとは

System Integrity Protectionは、macOSのセキュリティ機能の一つで、システムファイルやプロセスを保護します。yabaiの一部機能はこの保護により制限されています。

## 必要な場面

### SIP無効化**不要**な機能
- ウィンドウのフォーカス移動
- ウィンドウの入れ替え・移動
- ウィンドウのリサイズ
- フローティング・フルスクリーン切り替え
- BSPレイアウト

### SIP無効化**必要**な機能
- スペース（デスクトップ）の切り替え
- ウィンドウの透明度変更
- Dockの非表示
- メニューバーの操作
- Mission Controlとの深い連携

## SIP部分無効化の手順

### 1. リカバリーモードで起動

#### Apple Silicon（M1/M2/M3など）の場合
1. Macを完全にシャットダウン
2. **電源ボタンを約10秒間長押し**（起動オプションが表示されるまで）
3. 「オプション」を選択
4. 「続ける」をクリック
5. 管理者アカウントでログイン

#### Intel Macの場合
1. Macを再起動
2. 起動音が鳴ったら **⌘ Command + R** を押し続ける
3. Appleロゴまたは回転する地球儀が表示されるまで待つ
4. 管理者アカウントでログイン

### 2. ターミナルを開く
リカバリーモードに入ったら：
- メニューバーから「ユーティリティ」→「ターミナル」を選択

### 3. SIPを部分的に無効化
ターミナルで以下のコマンドを実行：

```bash
csrutil enable --without fs --without debug --without nvram
```

**実行結果例：**
```
Successfully enabled System Integrity Protection.
Please reboot for the changes to take effect.
```

### 4. 再起動
```bash
reboot
```

### 5. 設定の確認
通常起動後、ターミナルで状態を確認：

```bash
csrutil status
```

**正常な場合の出力：**
```
System Integrity Protection status: enabled (fs/debug/nvram excluded).
```

### 6. yabaiのスクリプティング追加機能を有効化

```bash
# スクリプティング追加機能を読み込み
sudo yabai --load-sa

# yabaiサービスを再起動
yabai --restart-service

# skhdサービスも再起動
skhd --restart-service
```

### 7. 動作確認

```bash
# スペース切り替えをテスト
yabai -m space --focus 2
```

エラーが出なければ成功です。

## セキュリティへの影響

### 無効化される保護
- **fs**: ファイルシステム保護の一部
- **debug**: デバッグ制限の一部
- **nvram**: NVRAM保護の一部

### 残る保護
- **kext**: カーネル拡張の署名要求
- **dtrace**: DTraceの制限
- **system**: システムファイルの保護（大部分）

### リスク軽減策
- 信頼できるソフトウェアのみインストール
- 定期的なセキュリティアップデート
- 不要になったら完全に有効化に戻す

## 元に戻す方法

### SIPを完全に有効化
リカバリーモードで：
```bash
csrutil enable
```

### 確認
```bash
csrutil status
# 出力: System Integrity Protection status: enabled.
```

## トラブルシューティング

### よくある問題

#### 1. リカバリーモードに入れない
- **Apple Silicon**: 電源ボタンを十分長く（10秒以上）押す
- **Intel**: Command + R のタイミングを調整

#### 2. csrutilコマンドが失敗する
```bash
# 現在の状態を確認
csrutil status

# 必要に応じて完全無効化してから部分無効化
csrutil disable
reboot
# 再度リカバリーモードで部分無効化
```

#### 3. yabaiでスペース切り替えができない
```bash
# スクリプティング追加機能の再読み込み
sudo yabai --uninstall-sa
sudo yabai --install-sa
sudo yabai --load-sa
yabai --restart-service
```

#### 4. macOSアップデート後に動かなくなった
- メジャーアップデート後はSIP設定がリセットされる場合があります
- 上記手順を再実行してください

## 注意事項

1. **バックアップ**: 重要なデータは事前にバックアップ
2. **アップデート**: macOSアップデート後は再設定が必要な場合があります
3. **企業環境**: 会社のMacでは管理者に確認してください
4. **セキュリティ**: 不要になったら元に戻すことを推奨

## 参考リンク

- [Apple公式: SIPについて](https://support.apple.com/en-us/HT204899)
- [yabai Wiki: SIP設定](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection)
- [csrutilコマンドリファレンス](https://www.unix.com/man-page/osx/8/csrutil/)