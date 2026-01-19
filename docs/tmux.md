# tmux設定

このファイルはtmuxターミナルマルチプレクサーの設定を管理します。

## ペイン分割

- `\`: ペインを縦に分割
- `-`: ペインを横に分割

## ペイン移動（Vimスタイル）

- `Ctrl-h`: 左のペインに移動
- `Ctrl-j`: 下のペインに移動
- `Ctrl-k`: 上のペインに移動
- `Ctrl-l`: 右のペインに移動

## ペインリサイズ（Vimスタイル）

- `H`: 左に5文字分縮小
- `J`: 下に5行分拡大
- `K`: 上に5行分縮小
- `L`: 右に5文字分拡大

## 表示設定

### 端末設定
- 256色端末を使用
- ステータスラインを非表示
- ウィンドウ番号の自動詰め機能有効

### カラー設定
- ステータスライン: 前景色14、背景色8 
- 非アクティブペインボーダー: 色12
- アクティブペインボーダー: 色13

## パフォーマンス設定

- Escキーの反応速度向上（delay 1ms）
- マウス操作有効

## プラグイン

### インストール済みプラグイン
- `tmux-plugins/tpm`: プラグインマネージャー
- `tmux-plugins/tmux-sensible`: 基本的な設定の改善
- `tmux-plugins/tmux-resurrect`: セッション保存・復元
- `tmux-plugins/tmux-sidebar`: サイドバー機能

### プラグイン管理
プラグインは`~/.tmux/plugins/tpm/tpm`で管理されます。

## AI使用量表示

tmuxのステータスバーにClaude Code、Copilot、Zed AIなどの使用量を表示します。

### 必要なツール

- [codexbar](https://github.com/1vket/codexbar): AI使用量を取得するCLIツール

```bash
# インストール
cargo install codexbar
# または
brew install codexbar
```

### 仕組み

1. **launchd**が60秒ごとに`scripts/ai-usage-cache.sh`を実行
2. キャッシュファイル`~/.cache/ai-usage.json`に使用量を保存
3. tmuxのステータスバーが`scripts/tmux-ai-usage.sh`でキャッシュを読み取り表示

### セットアップ

`setup.sh`を実行すると自動的にlaunchdが設定されます。手動で設定する場合:

```bash
# シンボリンク作成
ln -sf ~/.dotfiles/launchd/com.dotfiles.ai-usage-cache.plist ~/Library/LaunchAgents/

# launchdに登録
launchctl load ~/Library/LaunchAgents/com.dotfiles.ai-usage-cache.plist

# 動作確認
launchctl list | grep ai-usage
```

### トラブルシューティング

**「AI: stale」と表示される場合**

キャッシュが古くなっています。launchdが動いているか確認:

```bash
launchctl list | grep ai-usage
```

動いていなければ再ロード:

```bash
launchctl unload ~/Library/LaunchAgents/com.dotfiles.ai-usage-cache.plist
launchctl load ~/Library/LaunchAgents/com.dotfiles.ai-usage-cache.plist
```

**「AI: --」と表示される場合**

キャッシュファイルが存在しません。codexbarがインストールされているか確認:

```bash
which codexbar
```

**ログの確認**

```bash
cat /tmp/ai-usage-cache.log
cat /tmp/ai-usage-cache.error.log
```