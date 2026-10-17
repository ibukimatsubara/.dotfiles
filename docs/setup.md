# セットアップガイド

このリポジトリは、macOSまたはUbuntuで最低限の開発環境を復元するための設定を管理します。

## 復元の流れ

```bash
cd ~
git clone https://github.com/ibukimatsubara/.dotfiles.git
cd .dotfiles
./install.sh
./setup.sh
```

`install.sh`はOSを判定してCLIツールをインストールします。`setup.sh`は既存設定をタイムスタンプ付きでバックアップしてから、リポジトリ内の設定へシンボリックリンクを作成します。

Node.jsは`fnm`で管理します。新規端末でNode.jsがまだ入っていない場合は、セットアップ後に`nvlts`を一度実行して最新LTSを導入します。

## DSHのセットアップ

tmuxの`Cmd+R`とZshの`dcode`は、DeepSeek Harnessの`dsh-tui`プロファイルを起動します。Node.js 22.19以上の22系、または24以上とnpmが必要です。

`install.sh`はDSHの導入も行います。DSHだけを導入する場合や、Node.jsの導入後に再実行する場合は、次のコマンドを使います。

```bash
bash scripts/setup-dsh.sh
source ~/.zshrc
tmux source-file ~/.tmux.conf
dcode
```

このスクリプトは、pnpm、`@deepseek-ai/dsh`、`@deepseek-harness-tui/dsh-tui`を確認し、未導入のツールと`dsh-tui`プロファイルをセットアップします。認証はTUI内の`/auth`から行います。DeepSeekアカウントを利用する場合は`/auth login deepseek-account`を使い、`/model`でアカウント用のモデルを選びます。APIキーは端末上で設定し、Gitへ保存しません。

`dsh-tui doctor`で導入状況を確認できます。APIキーの未設定表示があっても、ブラウザログインを利用する場合はAPIキーの設定は不要です。

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

## Ghosttyのキー操作を別のMacで復元する

`Ctrl+H/J/K/L` と `Ctrl+U/I` の条件付き操作は、Codex自身の設定ではなくHammerspoonが実装している。Ghosttyのtmux外でキーを受け取り、AeroSpaceへフォーカス・ワークスペース移動を依頼する。tmux内ではキーを通し、tmuxがペイン・セッション移動を処理する。

`install.sh`でHammerspoonとAeroSpaceを導入し、`setup.sh`で設定をリンクして両アプリを起動する。Hammerspoon CLIが使える場合は設定の再読み込みも予約する。CLIが使えない場合や接続に失敗した場合は、Hammerspoonのメニューから `Reload Configuration` を実行する。`hammerspoon/init.lua` はHammerspoonのログイン時自動起動を有効にする。キー処理に使う拡張は起動時に読み込み、最初のキー入力中の初回ロードを避ける。

新しいMacでは、システム設定の「プライバシーとセキュリティ → アクセシビリティ」でHammerspoonとAeroSpaceを許可する。権限はGit経由では復元できない。Hammerspoonを許可した後はアプリを終了・再起動する。

```bash
open -g -a Hammerspoon
hs -A -t 3 -c 'return hs.inspect({autoLaunch=hs.autoLaunch(),accessibility=hs.accessibilityState(),navigation=ghosttynavigation and ghosttynavigation.status(),secureInput=hs.eventtap.isSecureInputEnabled()})' </dev/null
```

`autoLaunch = true`、`accessibility = true`、`navigation.enabled = true` が期待値。Ghosttyのtmux外で確認すると `route = "aerospace"` になる。`secureInput = true` の間はキー監視が遮断されるため、パスワード入力欄や発生元のアプリを確認する。

キーがCodexへ届いて「disabled」と表示される場合の確認・復帰手順は、[Aqua Voice・AeroSpace トラブルシューティング](./aqua-voice-aerospace-troubleshooting.md#ghosttyのctrlhlでcodex-cliにdisabledと表示される)を参照する。これらは起動・権限・初回ロードの不足を減らす対策であり、未再現の一時的な取り逃がしが完全になくなると断定するものではない。

## Ubuntuについて

シェル、tmux、VS Code設定は共通です。skhd、Hammerspoon、LaunchDaemonによるblocklistはmacOS専用なのでスキップされます。VS CodeやChrome本体が未導入の場合は、各公式配布元から先にインストールしてください。

## ロールバック

既存設定は`*.bak-YYYYMMDD-HHMMSS`として同じディレクトリへ移動されます。問題があればシンボリックリンクを外し、バックアップを元の名前へ戻します。

## 共通・macOS・Ubuntuの分離

入口の `./install.sh` と `./setup.sh` は共通です。OSを判定し、`platforms/common/` と `platforms/macos/` または `platforms/ubuntu/` を読み込みます。Ubuntu/Debian以外のLinuxはセットアップ前に停止します。

設定の編集場所と反映方法は [platforms.md](platforms.md) を参照してください。VS Codeの設定は合成するため、変更後は `./setup.sh` の再実行が必要です。UbuntuではHomebrewやmacOSのサービスは実行しません。
