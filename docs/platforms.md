# 共通・macOS・Ubuntuの設定

1つのmainブランチで両OSを管理します。実行するコマンドはどちらでも同じです。

```bash
./install.sh
./setup.sh
```

`uname` とLinuxの `/etc/os-release` で選択します。macOSは `macos`、Ubuntu/Debianとその派生は `ubuntu` プロファイルです。対象外のOSでは、パッケージのインストールや設定の変更前に停止します。

## 編集する場所

| 対象 | 共通 | macOS | Ubuntu |
|---|---|---|---|
| インストール | `platforms/common/install.sh` | `platforms/macos/install.sh` | `platforms/ubuntu/install.sh` |
| セットアップ | `platforms/common/setup.sh` | `platforms/macos/setup.sh` | `platforms/ubuntu/setup.sh` |
| Ghostty | `platforms/common/ghostty.conf` | `platforms/macos/ghostty.conf` | `platforms/ubuntu/ghostty.conf` |
| tmux | `tmux/tmux.conf` | `platforms/macos/tmux.conf` | `platforms/ubuntu/tmux.conf` |
| Zsh | `zsh/`、`platforms/common/zsh.zsh` | `platforms/macos/zsh.zsh` | `platforms/ubuntu/zsh.zsh` |
| VS Code | `vscode/settings.json` | `platforms/macos/vscode-settings.json` | `platforms/ubuntu/vscode-settings.json` |

Neovim・Vimium C・VS Codeのキーバインドと拡張機能一覧も共有します。macOS専用のHammerspoon・AeroSpace・SketchyBar・skhdなどは、既存のツール別ディレクトリに残し、macOSのsetupだけから適用します。

## 読み込みと反映

- **Ghostty**: `ghostty/config`（macOS）と `ghostty/config-linux`（Ubuntu）が共通設定、OS別設定の順にincludeします。`./setup.sh` は対応する入口ファイルを設定先にリンクします。既存の連携パスも維持します。編集後はGhosttyを再読み込みしてください。
- **tmux**: 共通設定の後、OS別設定を読み込み、最後にTPMを初期化します。既存のwatcherが共通・OS別の両ファイルの変更を検知します。手動反映は `tmux source-file ~/.tmux.conf` です。
- **Zsh**: 共通PATH → 共通config・alias・function → OS別設定 → `~/.zshrc.local` → fnmなどの初期化、の順です。新しいシェルを開いて反映します。UbuntuではKeychain・Simulator・macOS壁紙の処理を読み込みません。
- **VS Code**: 共通JSONとOS別JSONをマージし、同じキーはOS別を優先します。生成先は `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/vscode/<OS>/settings.json` です。User設定はそこへリンクします。編集後は `./setup.sh` を再実行してください。

Ghosttyの設定先とUbuntuのVS Code設定先は `XDG_CONFIG_HOME` に対応します。それ以外の既存ツールの配置は従来どおりです。個人の秘密情報やマシン固有値は `~/.zshrc.local` へ置きます。

UbuntuではCLIツールとWayland/X11のクリップボードツールをaptで導入します。Ghostty・VS Code・Chrome・Nerd Fontの導入は引き続き手動です。ログインシェルの変更は `chsh -s "$(command -v zsh)"` を実行し、ログインし直してください。

## 検証

```bash
python3 scripts/test-platform-config.py
bash scripts/test-tmux-config-watch.sh
jq empty vscode/settings.json vscode/keybindings.json chrome/vimium-c.json \
  platforms/macos/vscode-settings.json platforms/ubuntu/vscode-settings.json
ghostty +validate-config --config-file=ghostty/config-linux
```

テストは一時HOMEと専用tmuxソケットを使い、実際のパッケージインストールやデスクトップサービスの起動を行いません。macOSのウィンドウ操作・HammerspoonとUbuntuのデスクトップ上のキー操作は、それぞれの実機で確認してください。
