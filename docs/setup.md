# セットアップガイド

## 必要な環境

インストール前に以下のソフトウェアが必要です：

- tmux
- neovim  
- zsh
- Nerd Font（アイコン表示用フォント）

## インストール手順

1. ホームディレクトリに移動
   ```bash
   cd ~
   ```

2. リポジトリをクローン
   ```bash
   git clone https://github.com/1vket/.dotfiles.git
   ```

3. dotfilesディレクトリに移動
   ```bash
   cd .dotfiles
   ```

4. セットアップスクリプトを実行
   ```bash
   sh setup.sh
   ```

## セットアップスクリプトの動作

`setup.sh`は以下の処理を実行します：

### Zsh設定
- `~/.zshrc`にdotfilesの読み込み設定を追加

### シンボリックリンク作成
- `~/.config/nvim/init.vim` → `~/.dotfiles/init.vim`
- `~/.tmux.conf` → `~/.dotfiles/tmux.conf`

### ディレクトリ作成
- `~/.config/nvim/`
- `~/.config/nvim/dein/`
- `~/.config/nvim/toml/`

### vim-plugインストール
- Neovim用プラグインマネージャーのインストール

## インストール後の作業

### Neovimプラグインのインストール
1. Neovimを起動
2. `:PlugInstall`を実行してプラグインをインストール

### tmuxプラグインのインストール
1. tmuxを起動
2. `Prefix + I`でプラグインをインストール（Prefixはデフォルトで`Ctrl-b`）

### フォント設定
Nerd Fontをターミナルエミュレーターで設定して、アイコンが正しく表示されることを確認してください。