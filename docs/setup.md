# セットアップガイド

このリポジトリは、macOSまたはUbuntuで最低限の開発環境を復元するための設定を管理します。

## 復元の流れ

```bash
cd ~
git clone https://github.com/1vket/.dotfiles.git
cd .dotfiles
./install.sh
./setup.sh
```

`install.sh`はOSを判定してCLIツールをインストールします。`setup.sh`は既存設定をタイムスタンプ付きでバックアップしてから、リポジトリ内の設定へシンボリックリンクを作成します。

Node.jsは`fnm`で管理します。新規端末でNode.jsがまだ入っていない場合は、セットアップ後に`nvlts`を一度実行して最新LTSを導入します。

## `setup.sh`が管理するもの

- Zsh
- tmuxとTPM
- VS Codeの設定、キーバインド、拡張機能
- Neovim（legacy）
- macOSのみ: Ghostty、Kitty（legacy）、skhd、Hammerspoon、break timer
- Claude Code / Codexの安全な設定部分

VS Codeのリンク先はOSごとに自動で切り替わります。

- macOS: `~/Library/Application Support/Code/User/`
- Ubuntu: `~/.config/Code/User/`

## 手動で必要な作業

次の情報はGitへ保存しないため、新しい端末で再認証または安全なバックアップから復元します。

- GitHub CLIのログイン
- SSH秘密鍵
- Codex / Claude Codeの認証
- Chrome、Tailscaleなどのアカウントログイン
- Vimium C設定のImport
- macOSのAccessibility / Input Monitoring権限

Vimium Cは`chrome/vimium-c.json`をOptionsページの`Import settings`から読み込みます。

## Ubuntuについて

シェル、tmux、VS Code設定は共通です。skhd、Hammerspoon、LaunchDaemonによるblocklistはmacOS専用なのでスキップされます。VS CodeやChrome本体が未導入の場合は、各公式配布元から先にインストールしてください。

## ロールバック

既存設定は`*.bak-YYYYMMDD-HHMMSS`として同じディレクトリへ移動されます。問題があればシンボリックリンクを外し、バックアップを元の名前へ戻します。
