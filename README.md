# Dotfiles

macOSとUbuntuのどちらでも、リポジトリをcloneして開発環境を復元できることを目標にした個人用dotfilesです。現在の中心はVS Code、Codex、Ghostty、tmuxです。

## Quick Start

```bash
cd ~
git clone https://github.com/1vket/.dotfiles.git
cd .dotfiles
./install.sh
./setup.sh
```

`install.sh`はmacOS / Ubuntuを判定してCLIツールを導入し、`setup.sh`は既存設定をバックアップしてから設定ファイルをリンクします。

## 共通・OS別の設定

`./install.sh` と `./setup.sh` がOSを自動判定し、共通処理と、そのOSのプロファイルだけを読み込みます。UbuntuとDebianは `ubuntu` プロファイルを使います。

- `platforms/common/`: 共通のインストール・リンク処理、Ghosttyの基本設定、ZshのPATH
- `platforms/macos/`: Homebrew、macOSデスクトップ連携、Ghostty・tmux・Zsh・VS Codeの差分
- `platforms/ubuntu/`: apt、Wayland/X11対応、Ghostty・tmux・Zsh・VS Codeの差分
- `zsh/`・`tmux/`・`vscode/`・`nvim/`: 両OSで共有する操作・設定

Hammerspoon・AeroSpace・SketchyBarなどのmacOS専用ディレクトリは既存パスを維持し、macOSプロファイルからだけセットアップします。OSごとにブランチを分ける必要はありません。

VS Codeの `settings.json` は共通JSONとOS別JSONから生成します。編集後は `./setup.sh` を再実行してください。詳しくは [OS別設定の編集と反映](docs/platforms.md) を参照してください。

## UbuntuのHyprland / Quickshell

Ubuntu 26.04では、`./platforms/ubuntu/install-desktop.sh` でHyprland・DankMaterialShell（Quickshell）・Vicinaeを追加できます。GNOMEは残り、ログイン画面でセッションを選びます。通常の `./setup.sh` はデスクトップを切り替えません。

導入状況、キー操作、ローカル設定は [Ubuntuデスクトップ](docs/ubuntu-hyprland-plan.md) を参照してください。

フリーレン・ユウカ壁紙の配布元と別マシンでの取得・設定手順、Caelestia での自動切替は [Desktop wallpapers](docs/wallpapers.md) に記録しています。

音付きPomoru（作業・休憩の終了音、1分前の予告音、手動進行、バー表示）の再導入は
[Pomoruのセットアップ](platforms/ubuntu/pomoru/README.md) を参照してください。音源・パッチ・ビルド用スクリプトも同梱しています。

## 管理プロファイル

### Core

- Git / Zsh
- tmux
- jq / fzf / zoxide / direnv
- uv
- VS Code / Codex

### Desktop

- Ghostty
- Chrome / Vimium C
- VS Codeの設定、tmux風キーバインド、拡張機能

### macOS

- skhd: `Cmd+1`〜`Cmd+3`のワークスペース単位のアプリ起動・フォーカス
- Hammerspoon: break timerとマイク自動選択
- blocklist: `/etc/hosts`とLaunchDaemonによるサイト制限

### Optional

- Claude Code
- Tailscale
- Remote SSH

### Legacy

- Neovim
- Kitty

legacyは既存環境の互換性のため残していますが、新しいセットアップの中心にはしません。

## 主なキーバインド

### tmux

- `Ctrl+h/j/k/l`: pane移動
- `Ctrl+u/i`: 前・次のsession
- `Prefix+s`: session選択

### VS Code

- `Ctrl+h/j/k/l`: editor group移動
- `Ctrl+u/i`: 前・次のeditor tab
- `Ctrl+Shift+h/j/k/l`: tabを隣のgroupへ移動
- `Ctrl+Shift+u/i`: tabを左右へ並べ替え

統合ターミナルではこれらを奪わず、tmuxやシェルへ渡します。

### Chrome / Vimium C

- `Ctrl+h/l`: 前・次のChrome tab
- `Ctrl+j/k`: 高速スクロール
- `f`: link hint

## 構成

```text
.dotfiles/
├── install.sh
├── setup.sh
├── platforms/          # common / macos / ubuntu
├── vscode/             # settings、keybindings、extensions
├── chrome/             # Vimium C exportと復元メモ
├── agents/skills/      # 未配置の旧skills（移管先を検討中）
├── codex/              # 未配置の旧custom agents、リモートMac用指示
├── claude/             # 未配置の旧custom agents
├── ghostty/
├── tmux/
├── zsh/
├── hammerspoon/
├── break-timer/
├── launchd/
├── scripts/
├── nvim/               # legacy
├── kitty/              # legacy theme
└── docs/
```

## Gitへ保存しないもの

- APIキー、アクセストークン
- SSH秘密鍵
- `~/.config/gh/hosts.yml`
- Codex / Claude Codeの認証・session履歴
- Chromeのprofile、Cookie、password、履歴
- machine固有のprivate設定

秘密情報はパスワードマネージャーまたは暗号化バックアップへ分離します。個人用のシェル設定は`~/.zshrc.local`へ置きます。

## AI agent設定

Codex / Claude Codeの共通指示、skills、statusline、plugin導入は、2026-10-21から
別リポジトリ [agent-env](https://github.com/ibukimatsubara/agent-env) で管理します。
このリポジトリの`setup.sh`は、`~/.codex`・`~/.claude`・`~/.agents`へ何も配置しません。

`claude/agents/`、`codex/agents/`、`agents/skills/`に残る定義は配置されていません。
`codex/remote-home-AGENTS.md`は`scripts/setup-open-local-sender.sh`がリモートMacへリンクします。

## ドキュメント

- [セットアップ](docs/setup.md)
- [音楽・Podcast（cliamp、rmpc・MPD、Ubuntu からの同期）](docs/music.md)
- [VS Code](vscode/README.md)
- [Chrome / Vimium C](chrome/README.md)
- [tmux](docs/tmux.md)
- [Remote Codex preview](docs/remote-codex-preview.md)
- [Zsh](docs/zsh.md)
- [skhd](docs/skhd.md)
- [Neovim（legacy）](docs/neovim.md)
