# Neovim設定

このファイルはNeovimエディタの設定を管理します。

## プラグインマネージャー

**Lazy.nvim** を使用しています。高速で遅延読み込み対応。

- 初回起動時に自動インストール
- 設定は `nvim/lua/plugins/` 配下でモジュール化

## ディレクトリ構造

```
nvim/
├── init.lua                  # エントリーポイント
├── init.vim.backup           # 旧vim-plug設定のバックアップ
├── lua/
│   ├── config/              # 基本設定
│   │   ├── options.lua      # エディタオプション
│   │   ├── keymaps.lua      # キーマップ
│   │   └── autocmds.lua     # 自動コマンド
│   └── plugins/             # プラグイン設定（モジュール化）
│       ├── colorscheme.lua  # Hatsune Mikuテーマ
│       ├── git.lua          # vim-signify
│       ├── copilot.lua      # GitHub Copilot
│       ├── lsp.lua          # LSP + nvim-cmp
│       ├── nvim-tree.lua    # ファイルエクスプローラー
│       ├── bufferline.lua   # タブライン
│       ├── img-clip.lua     # 画像ペースト
│       └── image.nvim       # 画像インライン表示
└── plugin/                  # 追加機能
    └── auto-reload.vim      # Claude Code連携用自動リロード
```

## 基本設定

### エディタ設定
- UTF-8エンコーディング
- 行番号と相対行番号を表示
- 自動インデント
- システムクリップボード使用
- 検索結果ハイライト
- 80文字目にガイドライン表示
- カーソル行ハイライト
- 256色対応

### リーダーキー
- リーダーキー: `,` (カンマ)

### タブとインデント
- タブをスペースに展開
- タブ幅: 2文字
- インデント幅: 2文字

## プラグイン一覧

### 🎨 カラースキーム
- **vim-colors-hatsunemiku**: 初音ミクテーマ（シアン系）
  - 背景透過設定済み

### 📝 Git統合
- **vim-signify**: Git差分を行番号横に表示
  - `+`: 追加行
  - `-`: 削除行
  - `~`: 変更行

### 🤖 AI補完
- **GitHub Copilot**: AI駆動のコード補完
  - `Tab`: 提案を受け入れ
  - `Ctrl+J`: 次の提案
  - `Ctrl+K`: 前の提案

### 🔧 LSP + 補完
- **nvim-lspconfig**: LSPクライアント
  - Python用（jedi-language-server / pyright）
- **nvim-cmp**: 補完エンジン
  - `Ctrl+]`: 補完メニュー表示
  - `Ctrl+N`: 次の候補
  - `Ctrl+P`: 前の候補
  - `Ctrl+Y`: 選択確定
  - `Ctrl+E`: キャンセル

LSPキーマップ：
- `gd`: 定義へジャンプ
- `gr`: 参照を検索
- `Shift+K`: ホバー情報を表示

### 📂 ファイル管理
- **nvim-tree.lua**: ファイルエクスプローラー
  - `<M-e>` (Option+E): トグル
  - Gitステータス表示
  - アイコン表示

- **bufferline.nvim**: タブライン
  - `<M-h>` (Option+H): 前のバッファ
  - `<M-l>` (Option+L): 次のバッファ
  - `<M-w>` (Option+W): バッファを閉じる

### 🖼️ 画像サポート（NEW!）

#### img-clip.nvim - 画像ペースト
クリップボードから画像を自動保存してMarkdownリンクを挿入

**使い方:**
1. スクリーンショットを撮る（Cmd+Shift+4など）
2. Neovimで `,p` を押す
3. → `assets/` フォルダに画像が保存される
4. → `![](assets/2025-11-14-23-30-45.png)` のようなリンクが挿入される

**設定:**
- 保存先: `assets/` （現在のファイルからの相対パス）
- ファイル名: 日付時刻（YYYY-MM-DD-HH-MM-SS.png）
- ドラッグ&ドロップにも対応

#### image.nvim - 画像インライン表示
Kitty Graphics Protocolを使ってターミナル内に画像を表示

**機能:**
- Markdownの画像リンクをインライン表示
- リモート画像も自動ダウンロード表示
- インサートモードでも表示継続
- 最大サイズ: 幅100文字、高さ12行

**対応ファイル形式:**
- PNG, JPG, JPEG, GIF, WebP

**対応ファイルタイプ:**
- Markdown, VimWiki

**依存関係:**
- ImageMagick (`brew install imagemagick`)
- luarocks (`brew install luarocks`)
- magick（Lazy.nvimが自動インストール）

## キーマップ

### ファイル操作
| キー | 機能 |
|------|------|
| `<M-e>` | ファイルエクスプローラー トグル |
| `<M-h>` | 前のバッファ |
| `<M-l>` | 次のバッファ |
| `<M-w>` | バッファを閉じる |

### 画像操作
| キー | 機能 |
|------|------|
| `,p` | クリップボードから画像をペースト |

### ファイルパスコピー
| キー | 機能 |
|------|------|
| `<M-p>` | ファイルの絶対パスをコピー |
| `<M-P>` | ファイルパス:行番号をコピー |
| `<M-y>` | 選択範囲をクリップボードにコピー（ビジュアルモード） |

### Claude Code連携
| キー | 機能 |
|------|------|
| `<M-c>` | 水平分割でClaude起動 |
| `<M-v>` | 垂直分割でClaude起動 |

### ファイルリロード
| キー | 機能 |
|------|------|
| `<M-r>` | ファイルをチェック&リロード |
| `<M-R>` | 強制リロード |

### Git操作
| キー | 機能 |
|------|------|
| `<M-g>s` | git status |
| `<M-g>d` | 現在ファイルのgit diff |
| `<M-g>b` | 現在ファイルのgit blame |

### その他
| キー | 機能 |
|------|------|
| `<M-d>` | 差分表示 |
| `<M-o>` | 読み取り専用モード切り替え |
| `<M-m>` | README.mdを開く |
| `<Esc>` | ターミナルモード終了 |

## プラグイン管理

### プラグインのインストール
```bash
# 初回起動時に自動インストール
nvim

# または手動で
nvim --headless "+Lazy! sync" +qa
```

### プラグインの更新
```vim
" Neovim内で
:Lazy update
```

### プラグインの状態確認
```vim
" Neovim内で
:Lazy
```

### ヘルスチェック
```vim
" Neovim内で
:checkhealth
:checkhealth lazy
```

## 画像機能の使い方（詳細）

### セットアップ
1. 依存関係がインストールされていることを確認
   ```bash
   convert --version  # ImageMagick
   luarocks --version # luarocks
   ```

2. Neovimを起動してLazy.nvimがプラグインをインストール
   - 初回起動時にluarocksとmagickが自動ビルドされる（数分かかる）

3. Kittyターミナルを使用していることを確認
   - 他のターミナルでは画像表示が機能しない

### 画像ペーストの実践例
```markdown
# ドキュメント作成の流れ

1. Markdownファイルを開く
   nvim docs/tutorial.md

2. スクリーンショットを撮る
   Cmd+Shift+4 (macOS)

3. Neovimで ,p を押す

4. 自動的に以下が挿入される:
   ![](assets/2025-11-14-23-30-45.png)

5. 画像がターミナル内に表示される！
```

### トラブルシューティング

**画像が表示されない場合:**
- Kittyターミナルを使用しているか確認
- ImageMagickがインストールされているか確認: `convert --version`
- `:checkhealth` でエラーを確認

**画像ペーストが動作しない場合:**
- クリップボードに画像があるか確認
- `assets/` ディレクトリが作成可能か確認
- `:messages` でエラーを確認

**magickのビルドに失敗する場合:**
```bash
# 手動でインストール
luarocks --local install magick
```

## パフォーマンス

- **起動時間**: ~30-50ms（Lazy.nvimの遅延読み込みにより高速）
- **メモリ使用量**: 約50-80MB（10プラグイン）
- **大容量ファイル**: synmaxcol=200で最適化

## 自動リロード機能

Claude Codeなど外部ツールとの連携のため、ファイルの自動リロードを設定済み。

- `autoread` 有効
- `updatetime` 100ms
- フォーカス変更、カーソル移動時に自動チェック
- 外部変更を検知して自動リロード

## トラブルシューティング

### プラグインがインストールされない
```bash
# Lazy.nvimを手動でクリーンインストール
rm -rf ~/.local/share/nvim/lazy
nvim
```

### LSPが動作しない
```bash
# Python LSPをインストール
pip install jedi-language-server
# または
pip install pyright
```

### Copilotが動作しない
```vim
" Neovim内で認証
:Copilot setup
```

### 設定を元に戻したい
```bash
# init.luaを削除すればinit.vimに戻る
rm ~/.config/nvim/init.lua
rm -rf ~/.config/nvim/lua
```

## 参考リンク

- [Lazy.nvim](https://github.com/folke/lazy.nvim)
- [img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim)
- [image.nvim](https://github.com/3rd/image.nvim)
- [Hatsune Miku theme](https://github.com/4513ECHO/vim-colors-hatsunemiku)
