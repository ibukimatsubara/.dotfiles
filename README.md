# Dotfiles

Macが使えなくなっても、リポジトリをcloneして最低限の開発環境を復元できることを目標にした個人用dotfilesです。現在の中心はVS Code、Codex、Ghostty、tmuxです。

## Quick Start

```bash
cd ~
git clone https://github.com/1vket/.dotfiles.git
cd .dotfiles
./install.sh
./setup.sh
```

`install.sh`はmacOS / Ubuntuを判定してCLIツールを導入し、`setup.sh`は既存設定をバックアップしてから設定ファイルをリンクします。

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

- skhd: `Cmd+1`〜`Cmd+5`のアプリ起動
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
├── vscode/             # settings、keybindings、extensions
├── chrome/             # Vimium C exportと復元メモ
├── agents/skills/      # Codex / Claude共通のpersonal skills
├── codex/              # Codexのinstructions、agents、安全な共通設定
├── claude/             # Claude Codeのinstructions、agents、statusline
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

`setup.sh`は以下のpersonal設定をglobal scopeへ配置します。

- `codex/AGENTS.md` → `~/.codex/AGENTS.md`
- `codex/agents/` → `~/.codex/agents/`へ同期
- `agents/skills/` → `~/.agents/skills/`
- `claude/CLAUDE.md` → `~/.claude/CLAUDE.md`
- `claude/agents/` → `~/.claude/agents/`へ同期
- 共通skills → `~/.claude/skills/`内へ個別同期

Codexの共通skillsは公式にsymlink対応しているためlinkを使い、agent定義と
Claude側のskillsはtoolごとのsymlink差異を避けるため内容比較後に同期します。

plugin cache、OAuth、認証情報、session履歴、Codexのmachine-managed
`config.toml`、Claudeの`settings.json`は追跡しません。公式pluginとLSPの再導入は
`scripts/setup-ai-agent-tools.sh`が担当します。

## ドキュメント

- [セットアップ](docs/setup.md)
- [VS Code](vscode/README.md)
- [Chrome / Vimium C](chrome/README.md)
- [tmux](docs/tmux.md)
- [Remote Codex preview](docs/remote-codex-preview.md)
- [Zsh](docs/zsh.md)
- [skhd](docs/skhd.md)
- [Neovim（legacy）](docs/neovim.md)
