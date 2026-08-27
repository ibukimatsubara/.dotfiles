# Remote Codex artifactsを手元Macで開く

## 目的

安定したリモートMac上でCodexをtmux内に常駐させ、Moshで操作する。生成した
PPTX、PDF、Markdown、HTMLなどの成果物だけをTailscale Taildropで手元Macへ
送り、手元のPowerPoint、ブラウザ、エディタで開く。

```text
remote Codex -> open-local -> Taildrop -> local receiver -> local open
```

Mosh自体はファイル転送やGUI転送を提供しないため、成果物転送にはTaildropを
使う。手元MacのRemote Loginや公開ポートは不要。

macOSのGUI版Tailscaleはサンドボックスのため任意パスを直接読めない。送信
スクリプトはファイルを標準入力でCLIへ渡し、`--name`で元のファイル名を保持する。

## 構成

- `scripts/open-local.sh`: リモート側の送信コマンド
- `scripts/taildrop-open-receiver.sh`: 手元Mac側の受信・検証・open処理
- `launchd/com.local.taildrop-open.plist`: 受信処理を常駐させるLaunchAgent
- `codex/remote-home-AGENTS.md`: リモートCodexへ`open-local`の使用を伝える指示
- `~/.config/open-local/config`: 送信先端末名。machine固有なのでGit管理しない

## 手元Macのセットアップ

```bash
~/.dotfiles/scripts/setup-taildrop-open-receiver.sh
```

受信したプレビューは`~/Downloads/svm-preview/`へ保存される。通常のTaildrop
ファイルは自動で開かず、`~/Downloads/Taildrop/`へ保存される。

自動オープン対象は次の拡張子だけ。

```text
pptx pdf md markdown html htm docx xlsx png jpg jpeg gif webp svg txt csv
```

## リモートMacのセットアップ

dotfilesをcloneまたは同期したあと、Taildropの送信先として手元MacのTailscale
端末名を渡す。

```bash
~/.dotfiles/scripts/setup-open-local-sender.sh <local-taildrop-device>
```

セットアップは`~/.local/bin/open-local`を作り、送信先を権限`0600`の
`~/.config/open-local/config`へ保存する。`~/AGENTS.md`が存在しない場合は、
Codex向け指示もリンクする。

## 使い方

リモートMac上で実行する。

```bash
open-local /absolute/path/to/report.pptx
open-local /absolute/path/to/report.md
open-local /absolute/path/to/report.html
```

同名のプレビューは手元Mac側で最新版に置き換える。現在は単独ファイルだけを
扱う。CSS、JavaScript、画像を別ファイルに持つHTMLやディレクトリ一式は未対応。

## 状態確認

手元Mac:

```bash
launchctl print "gui/$UID/com.local.taildrop-open"
tail -f ~/Library/Logs/svm-open-receiver.log
```

リモートMac:

```bash
cat ~/.config/open-local/config
tailscale file cp --targets
```

macOS版TailscaleでCLI integrationを入れていない場合は、次のフルパスでも確認
できる。

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale file cp --targets
```

## 停止・再開

手元Macで受信処理を停止:

```bash
launchctl bootout "gui/$UID/com.local.taildrop-open"
```

再開:

```bash
launchctl bootstrap "gui/$UID" ~/Library/LaunchAgents/com.local.taildrop-open.plist
```

## セキュリティ

- Taildropは自分が所有するTailscale端末間の転送に限定される。
- `svm-open--<timestamp>--`で始まる転送だけを自動オープン候補にする。
- 許可拡張子以外は保存のみで、自動的に開かない。
- 受信先と一時領域はユーザー専用権限で作成する。
- 秘密情報や認証ファイルを`open-local`へ渡さない。
- HTMLはローカルブラウザで実行されるため、信頼できる生成物だけを開く。

TaildropはmacOS受信時の中断再開に対応していないため、転送が失敗した場合は
`open-local`をもう一度実行する。
