# 音楽・Podcast プレイヤー

ローカル音楽と Podcast を同じ画面で使う場合は **cliamp** を使う。音楽フォルダ・プレイリスト・Podcast の購読リストは Ubuntu を正本にし、各 Mac が日次で取得する。MPD + rmpc も音楽専用プレイヤーとして利用できる。

## cliamp で音楽・Podcast を聴く

macOS・Ubuntu ともに `./install.sh` → `./setup.sh` で導入する。macOS は公式 Homebrew tap、Ubuntu は SHA-256 を固定した公式 v2.3.0 の Linux バイナリ（x86_64・ARM64）を使う。Ubuntu では PipeWire または PulseAudio へ音を流す ALSA ブリッジも導入する。以下は v2.3.0 で確認した操作。

```bash
cd ~/.dotfiles
git pull --ff-only
./install.sh
./setup.sh

# 音楽。保留中の同期設定を反映して Music プレイリストを開く
music

# Podcast を直接開く
music --provider podcast

# ジャンル別プレイリストを直接開く
music --playlist Lofi
music --playlist Chill
```

Zsh では `m` で始まる短いコマンドも使える。`zsh/aliases/music.zsh` は新しいシェルで自動的に読み込まれる。今のシェルへ反映する場合は `source ~/.dotfiles/zsh/aliases/music.zsh` を実行する。

| コマンド | 開く内容 |
| --- | --- |
| `mmusic` | 音楽全体（Music プレイリスト） |
| `mlofi` | Lofi プレイリスト |
| `mchill` | Chill プレイリスト |
| `mpodcast` | Podcast プロバイダー |

`music` は起動前にダウンロード済みの共有設定を適用してから cliamp を実行する。起動時に Ubuntu への接続は行わない。引数を付けた場合は、その引数を cliamp へ渡す。通常の `cliamp` も利用できるが、実行中に保留された更新をすぐ適用するには、いったん終了して `music` で開く。

`music`・`music-sync` コマンドと `m` 付きエイリアスは両 OS で共通。プレイリストは Ubuntu の正本、または Mac が取得した内容を使う。日次の Ubuntu → Mac 取得ジョブは macOS 専用で、各 Mac で明示的に有効化する。

初回セットアップでは Music プレイリストと空の購読ファイルを作る。参照先は Ubuntu が `~/Music`、Mac が `~/Music/Shared`。既存のファイルは上書きしない。別のフォルダを正本にする場合は、Ubuntu のプレイリストをその場所へ変更する。

| キー | 動作 |
| --- | --- |
| `O`（Shift+o） | Podcast プロバイダーを開く |
| `F`（Shift+f） | 購読済み Podcast 一覧 |
| `/` → 番組名 → `Enter` | Podcast を検索 |
| 番組を選んで `f` | 購読・購読解除。共有する変更は Ubuntu 側で行う |
| 番組を選んで `Enter` | エピソードを一覧表示。エピソードを選んで `Enter` で再生 |
| `Space` | 一時停止・再開 |
| `q` | 終了 |

Rebuild の公開 RSS は **https://feeds.rebuild.fm/rebuildfm**（[公式サイトの Subscribe](https://rebuild.fm/#subscribe)）。購読は `podcast_subscriptions.json` に保持される。音楽は取得後オフラインでも再生できるが、Podcast は RSS・音声へのインターネット接続が必要。エピソード音声の自動ダウンロードは、この同期には含めない。

## MPD + rmpc を使う

macOS・Ubuntu で MPD を再生エンジン、rmpc をターミナル画面として使う。キー操作とレイアウトは共有し、音声出力と自動起動だけ OS ごとに変える。音源は `~/Music` 以下から読み込む。

## 別の端末で導入する

既に clone 済みの場合は、次の順で実行する。未導入なら先にリポジトリを `~/.dotfiles` へ clone する。

```bash
cd ~/.dotfiles
git pull --ff-only
./install.sh
./setup.sh
```

| OS | パッケージの導入 | 音声出力 | 自動起動 |
| --- | --- | --- | --- |
| macOS | Homebrew の `mpd`・`rmpc` | CoreAudio | `brew services` |
| Ubuntu | apt の `mpd`、rmpc 公式の静的 Linux バイナリ | PulseAudio / PipeWire の PulseAudio 互換サービス | systemd のユーザーサービス |

Ubuntu の rmpc は `scripts/install-rmpc.sh` が公式リリース **v0.11.0** を SHA-256 確認後に `~/.local/bin/rmpc` へ導入する。x86_64・ARM64 に対応し、既存の `rmpc` が PATH 上にあればそのまま使う。設定は v0.11.0 で確認済み。古い rmpc が入っている場合は同等以降へ更新する。

初回導入直後の Ubuntu で現在のシェルが `~/.local/bin` を認識していなければ、次を一度実行する。新しく開く Zsh では dotfiles が PATH を追加する。

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 起動

```bash
rmpc
```

MPD はユーザーのログイン時に自動起動する。接続できない場合は OS に応じて再起動する。

```bash
# macOS
brew services restart mpd

# Ubuntu（デスクトップのユーザーセッション内）
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-mpd.service
systemctl --user restart dotfiles-mpd.service
```

## キー操作

| キー | 動作 |
| --- | --- |
| `h` / `j` / `k` / `l` | フォルダ・項目の移動 |
| `2` | 音楽フォルダ一覧 |
| `3` / `5` | アーティスト一覧・アルバム一覧 |
| `7` | ローカルライブラリの Search 画面 |
| `a` | 選択した曲・フォルダをキューへ追加 |
| `1` → `Enter` | キューの選択曲を再生 |
| `p` | 一時停止・再開 |
| `>` / `<` | 次の曲・前の曲 |
| `.` / `,` | 音量を上げる・下げる |
| `u` | ライブラリを更新 |
| `?` | キー操作一覧 |
| `q` | 画面を閉じる。再生は続く |

Ghostty の `Ctrl+u` はウィンドウ操作に使うため、rmpc では通常の `u` にライブラリ更新を追加している。その他は標準の Vim 風キー操作を使う。上下移動は一覧の端でループする。

Search は MPD が読み込んだローカル音源が対象。曲名・アーティスト・アルバムなどのタグで絞り込む。タグのない音源をファイル名で探す場合は `Filename` 欄を使う。

追加した音源が見えない場合は `u`、またはシェルで次を実行する。MPD の自動ファイル監視は Linux 用なので、macOS では明示的に更新する。

```bash
rmpc update
```

再生を停止してから画面を閉じる場合は `s` → `q`。MPD 自体を止める場合は、macOS で `brew services stop mpd`、Ubuntu で `systemctl --user stop dotfiles-mpd.service`。

## 設定の管理

`./install.sh`・`./setup.sh` が共通設定と検出した OS のプロファイルを適用する。

- `mpd/mpd.conf`: 共通のライブラリ・保存先・接続設定。
- `platforms/<OS>/mpd-output.conf`: OS 別の音声出力。Ubuntu はライブラリの自動監視も有効にする。
- `platforms/common/setup.sh`: 上の 2 ファイルを `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/mpd/<OS>/mpd.conf` へ合成する。生成物に `${XDG_CONFIG_HOME:-$HOME/.config}/mpd/mpd.conf` と `~/.mpdconf` をリンクする。手動編集は元の共通設定・OS 別設定に行い、`./setup.sh` 後に MPD を再起動する。
- `rmpc/config.ron` → `${XDG_CONFIG_HOME:-$HOME/.config}/rmpc/config.ron`。マウス・ジャケット表示を無効にし、キューは曲一覧だけのレイアウトにする。
- `platforms/ubuntu/dotfiles-mpd.service`: Ubuntu 用のユーザーサービス。`~/.mpdconf` を明示して起動する。
- データベース・保存済みプレイリスト: `~/.local/share/mpd/`
- 再生状態・ログ・PID: `~/.local/state/mpd/`

接続には `~/.local/state/mpd/socket` を使う。Ubuntu の apt パッケージがシステム用 MPD を起動していても、TCP ポートを奪い合わない。音量はソフトウェアミキサーを使い、再起動後は自動再生せず一時停止状態で復元する。

Ubuntu の音声再生は、PulseAudio または PipeWire の PulseAudio 互換サービスが動くデスクトップのユーザーセッションを前提とする。ヘッドレス・SSH 環境でユーザーサービスに接続できない場合は、デスクトップへログインしてから上の systemctl コマンドを実行する。

## Ubuntu から Mac へ毎日同期する

Ubuntu の音楽フォルダを正本にし、Tailscale 経由の SSH と rsync で各 Mac にローカルコピーを置く。取得済みの曲はオフラインでも rmpc で再生できる。音源を Git に入れる必要はない。

cliamp を使う場合、同期した音源だけを開くコマンドは `cliamp ~/Music/Shared`。`~/Music` 全体を指定すると、元から Mac にある録音・効果音なども読み込まれる。フォルダをプレイリストに登録する場合も、同期先の `~/Music/Shared` 以下を参照する。

### 初回設定

1. Ubuntu に共有用のフォルダ（例: `~/Music/Shared`）を作り、同期したい音楽とジャケットを置く。`~/Music` 全体にはアプリのデータも含まれるため、専用フォルダを使う。
2. 両側で `./install.sh` を実行し、rsync 3 以降を導入する。Mac は Homebrew、Ubuntu は apt を使う。Mac 標準の古い rsync では動かない。同期処理と plist の生成には Python 3 も必要。
3. Mac で `./setup.sh`、または次の単独セットアップを実行する。設定テンプレートと `~/.local/bin/music-sync` を作る。自動同期はまだ有効にならない。

```bash
~/.dotfiles/scripts/setup-music-sync.sh --setup
```

`${XDG_CONFIG_HOME:-$HOME/.config}/music-sync/config` を編集する。これは端末ごとの Bash 設定であり、Git には含めない。既存設定はセットアップを再実行しても上書きしない。

```bash
MUSIC_SYNC_HOST="music-ubuntu"
MUSIC_SYNC_REMOTE_DIR="Music/Shared"
MUSIC_SYNC_LOCAL_DIR="$HOME/Music/Shared"

# Ubuntu 側の cliamp 設定を準備してから有効にする
MUSIC_SYNC_CLIAMP=1
MUSIC_SYNC_REMOTE_CLIAMP_DIR=".config/cliamp"
```

`music-ubuntu` は例。自分の SSH エイリアスか `ユーザー名@UbuntuのTailscaleホスト名` に置き換える。接続先ポートや鍵を変える場合は `~/.ssh/config` で設定する。相対パスは Ubuntu の SSH ユーザーのホームを起点とする。`~/Music/Shared` や絶対パス、空白・日本語を含むパスにも対応する。

### Ubuntu 側で共有するプレイリスト・購読を準備する

音源の同期元フォルダに合わせ、Ubuntu の `~/.config/cliamp/playlists/` に TOML ファイルを作る。例えば同期元が `Music/Shared` の場合は次の内容にする。

```toml
# ~/.config/cliamp/playlists/Music.toml
[[dir]]
path = "~/Music/Shared"
```

`Lofi.toml` や `Chill.toml` は、それぞれ音源フォルダ内のジャンル別サブフォルダを指定する。フォルダを参照する形式なので、その中へ曲を追加すればプレイリストにも現れる。複数の `[[dir]]` を並べてまとめることもできる。

Ubuntu の cliamp で番組を購読すると、同じ設定ディレクトリに `podcast_subscriptions.json` が作られる。まだ購読がない場合だけ、このファイルを `[]` で作成する。既存の購読リストは上書きしない。`playlists/` または購読ファイルが欠けている場合、同期処理はエラーにして Mac の設定を保持する。Python **3.11 以降**が両側で必要。

`MUSIC_SYNC_CLIAMP=1` にすると、以下を音源と同じ日次ジョブで取得する。既存の設定ファイルには自動で追記しないため、音源だけの既存設定では明示的に有効にする。

| データ | 同期・反映方法 |
| --- | --- |
| `playlists/*.toml` | 音源内のパスを Mac の同期先へ変換。Ubuntu の絶対パス・`~/`・`$HOME`・音源フォルダの symlink に対応 |
| `podcast_subscriptions.json` | 購読リストを Ubuntu の内容で置き換える。購読解除も反映 |
| 削除したプレイリスト | 以前に同期で管理したファイルだけ削除。Mac 専用の別名プレイリストは保持 |
| 再生履歴・Podcast の再生位置・再生キュー・音量・認証情報 | 各端末に保持 |

音源フォルダ外のローカルパスを含むプレイリストは、壊れたパスを渡さないようエラーにする。HTTP/HTTPS のストリームは保持する。共有するプレイリストの変更や購読・解除は Ubuntu 側で行う。Mac 側の同名ファイルは次回同期で上書きされ、変更前の内容は `${XDG_STATE_HOME:-$HOME/.local/state}/music-sync/backups/` へ保存する。

Mac の cliamp が実行中なら設定を保留し、終了後の `music` 起動時に適用する。日次の取得が成功していても、画面に反映されるのは次回起動からになる。`music-sync --apply-config` でも、ネットワーク接続なしで保留分を適用できる。実行中の判定は標準の `cliamp.sock.pid` を使うため、IPC ソケットのパスを独自変更した起動は対象外。

Mac の保存先は cliamp と同じく `CLIAMP_CONFIG_DIR` → `$XDG_CONFIG_HOME/cliamp` → `~/.config/cliamp` の順。独自の `CLIAMP_CONFIG_DIR` を使う場合は、その環境変数を設定してから日次ジョブを有効化する。Ubuntu 側の保存先が標準と異なる場合は `MUSIC_SYNC_REMOTE_CLIAMP_DIR` を変更する。

### 接続と初回同期

Tailscale への接続に加え、Ubuntu に SSH 接続できる設定が必要。既存の OpenSSH または有効化済みの Tailscale SSH を利用できる。最初に手動 SSH で接続先を確認し、次にプロンプトなしで接続できることを確認する。自動実行では `BatchMode=yes` を指定し、パスワード入力を待たない。SSH のホスト鍵確認は無効化しない。

```bash
# config に書いた接続先へ置き換える
ssh music-ubuntu true
ssh -oBatchMode=yes music-ubuntu true

# 初回の転送内容を確認してから実行
~/.local/bin/music-sync --dry-run
~/.local/bin/music-sync

# この Mac で毎日の同期を有効化
~/.dotfiles/scripts/setup-music-sync.sh --enable
```

### 実行タイミングと同期の方向

- Mac のローカル時刻で毎日 **09:00** に実行する。予定時刻にスリープ中なら、復帰時に実行する。
- ログイン時・有効化直後にも確認し、その日まだ成功していなければ実行する。同じ接続先・フォルダで成功済みなら、その日の自動転送は省略する。
- Ubuntu 停止中・Tailscale 未接続・認証エラーなどで失敗した場合は、成功済みにしない。次の予定時刻・ログイン時、または手動の `music-sync` で再試行する。接続復旧直後の常時監視は行わない。
- `music-sync` の手動実行は、同じ日でもすぐに転送する。`--dry-run` は音源の転送内容だけを確認し、プレイヤー設定の取得・変更や成功状態の更新は行わない。
- 手動同期と自動ジョブが重なった場合は、後から起動した処理を省略する。実行中の処理が終了・異常終了すると OS がロックを解放する。
- 中断した転送の一時ファイルは `${XDG_STATE_HOME:-$HOME/.local/state}/music-sync/partial/` に保管する。音楽フォルダには置かないため、未完了の曲がプレイヤーに混ざらない。
- **Ubuntu → Mac の一方向**。同じパスのファイルは正本の更新で置き換わるが、Ubuntu で削除した曲や Mac にだけある曲を Mac から自動削除しない。Mac で追加した曲は Ubuntu へ別途置く必要がある。
- 転送成功後に MPD を更新する。MPD に接続できなかった場合も未完了として扱い、MPD 起動後に手動で再試行できる。再生状態や MPD のデータベースは同期しない。

Mac ごとに設定と有効化を行う。以後 `./setup.sh` は、その Mac で有効にした LaunchAgent を再登録する。設定・スクリプトだけを他の端末へ持っていっても、未設定の接続先へ通信しない。

```bash
# 状態・ログを確認
launchctl print "gui/$(id -u)/com.local.music-sync"
tail -n 50 "${XDG_STATE_HOME:-$HOME/.local/state}/music-sync/sync.log"

# 自動同期を停止（音源・設定・履歴は残す）
~/.dotfiles/scripts/setup-music-sync.sh --disable
```

LaunchAgent の設定読み込みエラーなどは、同じディレクトリの `agent.log` を確認する。実行時刻を変更する場合は `launchd/com.local.music-sync.plist` の `StartCalendarInterval` を編集し、`--enable` を再実行する。

管理するファイルは、同期処理の `scripts/music-sync.sh`、プレイヤー設定用の `scripts/music-player-sync.py`、起動用の `scripts/music-player.sh`、導入・停止用の `scripts/setup-music-sync.sh`、設定例の `music-sync/config.example`、plist テンプレートの `launchd/com.local.music-sync.plist`。plist は各端末の実パスに展開して `~/Library/LaunchAgents/` へ配置する。可変のプレイリスト・購読リストの正本は Ubuntu に置く。

Ubuntu の正本に対するバックアップは別途用意する。削除を反映しないコピーは、全世代の復元を保証するバックアップではない。

## 検証

```bash
python3 scripts/test-music-setup.py
python3 scripts/test-music-sync.py
python3 scripts/test-music-player-sync.py
python3 scripts/test-platform-config.py
for script in install.sh setup.sh scripts/install-rmpc.sh scripts/install-cliamp.sh scripts/music-sync.sh scripts/setup-music-sync.sh scripts/music-player.sh; do
  bash -n "$script" || break
done
rmpc status
rmpc outputs
```

音楽設定のテストは一時 HOME で OS 別の合成、空白を含むパス、既存設定のバックアップ、再実行、ダウンロード失敗を確認する。実際のサービスや音声出力は変更しない。Ubuntu 用 tmux テストは Linux の `/usr/bin/zsh` がないホストではスキップする。

同期テストはネットワーク通信をしない SSH 代替処理と実際の rsync を使い、転送・更新、手元の曲の保持、日次の重複防止、失敗後の再試行、プレビュー、plist の生成と無効化を確認する。自分の Ubuntu への SSH 認証・Tailscale 接続は別途確認する。

プレイヤー設定のテストは音源パスの変換、曲順・ブックマークの保持、実行中の更新保留、起動時のオフライン反映、共有リストの削除・バックアップ、不正な入力の拒否を確認する。実ユーザーのプレイヤーは操作しない。

参考: [rmpc](https://github.com/mierak/rmpc)、[v0.11.0 の公式バイナリ](https://github.com/mierak/rmpc/releases/tag/v0.11.0)、[MPD](https://mpd.readthedocs.io/en/stable/user.html)、[Homebrew MPD](https://formulae.brew.sh/formula/mpd)、[Ubuntu の MPD パッケージ](https://packages.ubuntu.com/noble/mpd)。

同期の参考: [rsync のマニュアル](https://download.samba.org/pub/rsync/rsync.1)、[Apple: Scheduling Timed Jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html)、[Tailscale SSH](https://tailscale.com/docs/features/tailscale-ssh)。
