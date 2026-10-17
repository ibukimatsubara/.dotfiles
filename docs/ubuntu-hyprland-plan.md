# Ubuntu: Hyprland + Quickshell デスクトップ

2026-10-17: Quickshell主体で進める方針を決定し、DankMaterialShell（DMS）を土台として導入した。日常の検索にはVicinaeを使う。macOS側の設定と、Ghostty・tmux・Zsh・VS Codeの共通設定は維持する。

## 構成

| 役割 | 使用するもの | macOS側との対応 |
|---|---|---|
| ウィンドウ・ワークスペース管理 | Hyprland | AeroSpace、skhd、JankyBorders |
| バー・通知・音量パネル・カレンダー・壁紙UI | DMS / Quickshell | SketchyBar、OS標準UI、Hammerspoonの一部 |
| 検索・計算・アプリ起動・クリップボード履歴 | Vicinae | Raycast |
| 日本語入力 | Fcitx5 + Mozc | OSの日本語入力 |
| ロック・アイドル制御 | hyprlock + hypridle | ロック画面、画面オフ |
| 範囲スクリーンショット | grim + slurp + wl-copy | 範囲撮影、保存とコピー |
| 音声・メディア | PipeWire / WirePlumber、wpctl、playerctl | 音量・入力機器・メディア操作 |
| 画面共有・ファイル選択 | xdg-desktop-portal-hyprland + GTK portal | アプリからの画面共有・ファイル選択 |

DMSを選んだ理由は、[Ubuntu 26.04向けの公式stable PPA](https://danklinux.com/docs/dankmaterialshell/installation#ubuntu)があり、Quickshell製のデスクトップ機能を一体で導入できるため。Caelestiaも候補にしたが、調査時点ではgit版Quickshell等の依存が必要だった。[Caelestiaの依存関係](https://github.com/caelestia-dots/shell)

DMSが通知・パネルを担当するので、Waybarとswayncを別途常駐させない。DMSのクリップボード履歴は `clsettings.json` で初期状態を無効にし、Vicinaeの履歴に統一する。

## 導入済みバージョン

このマシンで確認した値:

- Ubuntu 26.04.1 LTS / GNOME Wayland（切り替え前のセッション）。
- Hyprland 0.53.3（Ubuntu apt）。
- DankMaterialShell 1.6.3、Quickshell 0.3.2（公式stable PPA）。
- Vicinae 0.29.1（公式インストーラー、`~/.local` 配下）。
- GPUはRTX 2060、現在のカーネルドライバはNouveau。ドライバの変更は行っていない。

Hyprland設定は0.53.x用のHyprlang形式。最新版dotfilesのLua設定をそのまま取り込まない。`setup-desktop.sh` は別系列のHyprlandを検出したら、設定を適用する前に停止する。

## このマシンで使い始める

パッケージ導入とユーザー設定の配置は済んでいる。作業を保存してからGNOMEをログアウトし、ログイン画面のセッション選択で **Hyprland** を選ぶ。自動ログアウト・再起動は行っていない。

ログインするとHyprlandのセッション内だけでDMS、Vicinae、Fcitx5、hypridleを起動する。GNOMEへ戻る場合はログアウトしてUbuntuセッションを選ぶ。Hyprlandからの退出コマンドは次のとおり。

```bash
hyprctl dispatch exit
```

通常のUbuntuセットアップとデスクトップの導入は分離している。別のUbuntu 26.04へ再現するときは:

```bash
./platforms/ubuntu/install-desktop.sh
```

設定だけを再配置する場合は:

```bash
./platforms/ubuntu/setup-desktop.sh
systemctl --user daemon-reload
```

インストーラーはDMSの公式stable PPAを登録し、aptパッケージを導入する。Vicinaeが未導入の場合は[公式Linuxインストーラー](https://docs.vicinae.com/install/linux)を使う。パスワードは保存しない。

## キー操作

Superは通常Windowsキー、MacキーボードではCommandに相当する。実際の認識は接続したキーボードで確認する。

| キー | 動作 |
|---|---|
| Super+1 / Super+Enter | Ghosttyの新規ウィンドウ |
| Super+2 | 現在のワークスペースのChromeへ移動、なければ新規ウィンドウ |
| Super+3 | 現在のワークスペースのVS Codeへ移動、なければ新規ウィンドウ |
| Super+Space | Vicinae（未導入ならfuzzel） |
| Super+Shift+Space | DMSのランチャー |
| Super+Shift+V | Vicinaeのクリップボード履歴 |
| Ctrl+Super+h/j/k/l | ウィンドウの方向移動 |
| Ctrl+Super+Shift+h/j/k/l | ウィンドウを方向へ移動 |
| Super+Alt+1〜9 | ワークスペース切替 |
| Super+Alt+Shift+1〜9 | ウィンドウを指定ワークスペースへ移動 |
| Ctrl+y/o（Ctrl+Super+y/oも可） | 前・次のワークスペース |
| Ctrl+f / Super+f | 余白を残す最大化 |
| Super+Shift+f | フローティング切替 |
| Super+q | 現在のウィンドウを閉じる |
| Super+ドラッグ / Super+右ドラッグ | ウィンドウ移動 / リサイズ |
| Super+, | DMS設定 |
| Super+n | 通知センター |
| Super+y | DMS壁紙選択 |
| Super+Alt+l | ロック |
| Print / Super+Shift+s | 範囲撮影、Pictures/Screenshotsへ保存してコピー |
| Super+Shift+Escape | DMSの電源メニュー |

macOSのAeroSpace/Hammerspoonと同じ操作へ合わせている。GhosttyではCtrl+h/j/k/lをタイルの方向移動（浮動ウィンドウを除外、端で循環）に使う。Ctrl+u/iは、ウィンドウタイトルが `[tmux] ` で始まる場合はtmuxへそのまま渡して前／次セッションへ切り替え、それ以外では前／次ワークスペースへ移動する。VS Code等の他アプリとVicinaeの検索画面では元のCtrlキー入力を渡す。tmuxを使う場合は先に `tmux` で入る必要がある。

GhosttyのSuper+t/rは既存tmuxの専用キーシーケンスに対応し、ペイン／エージェントのproject pickerを開く。Super+vは貼り付け、Super+wはウィンドウを閉じる。従来のCtrl+Shift+t/r/wも残す。Super+数字は既存macOSのアプリ起動を優先し、ワークスペースはSuper+Alt+数字へ分ける。

別ソケットの検証用tmuxと実際のGhosttyで、Ctrl+iによるalpha→beta、Ctrl+uによるbeta→alphaのセッション切り替えを確認済み。

## 設定の場所

```text
platforms/ubuntu/
  install-desktop.sh       # 明示的なパッケージ導入
  setup-desktop.sh         # リンク・初期値配置、再実行可能
  hypr/
    hyprland.conf          # 共通の入口（0.53.x）
    conf/                  # appearance / input / bindings / rules
    hypridle.conf
    hyprlock.conf
  dms/
    settings.json          # DMS初期値
    clsettings.json        # DMS履歴を無効化する初期値
  vicinae/vicinae.json     # Vicinae初期値
  fcitx5/profile           # USキーボード + Mozc初期値
scripts/
  hyprland-focus-or-open.sh
  hyprland-session.sh
  ubuntu-launcher.sh
  ubuntu-lock.sh
  ubuntu-screenshot.sh
```

`XDG_CONFIG_HOME` があれば設定先として使い、なければ `~/.config` を使う。Hyprlandの生成入口は `~/.config/dotfiles/hypr/hyprland.conf`（XDG指定時は同じ相対位置）に置き、そこからリポジトリ設定とローカル設定を順に読み込む。

モニター・キーボード等のマシン固有設定は `${XDG_CONFIG_HOME:-$HOME/.config}/hypr/local.conf` に置く。このファイルは最後に読み込み、セットアップを再実行しても上書きしない。

```ini
# 例: 実際の出力名は hyprctl monitors で確認する。
# monitor = DP-1, preferred, auto, 1
# input:kb_layout = jp
```

DMS・Vicinae・Fcitx5の設定はリポジトリへリンクせず、ファイルがない場合だけ初期値をコピーする。GUIによる変更を次回setupで消さない。追跡中の初期値の変更は既存設定へ自動反映されないため、既存設定へ必要な項目をマージする。

## セッションと日本語入力

DMSパッケージはgraphical-session向けの自動起動を含むため、このユーザーでは `dms.service` をmaskし、Hyprland内のセッション監視スクリプトから直接起動する。`dms doctor` がmasked/inactiveを報告するのはこの構成では想定どおり。GNOME起動時にDMSを重ねないための設定。

日本語入力はFcitx5 + Mozc。Hyprland内でGNOMEのIBus用環境変数を上書きし、DBus起動アプリにもディスプレイ・入力方式を渡す。GNOME側のIBus設定自体は変更しない。初期の切り替えはFcitx5標準のCtrl+Space。GUI設定は `fcitx5-configtool`。

Vicinaeの入力注入サーバーは初期状態で無効。履歴から選んだ内容はコピーし、アプリ側の貼り付けキーで貼り付ける。自動貼り付け・スニペット展開を使いたい場合は、その機能の入力権限を別途設定する。

セッションの切り替え後は、Ghostty・Chrome・VS Codeそれぞれの日本語入力を確認する。Electron等のWayland入力は起動方法やバージョンにも依存するため、実画面での確認が必要。

## 検証結果と未確認の範囲

確認済み:

- 依存パッケージ導入、Hyprlandのログインセッションエントリ。
- `Hyprland --verify-config` による0.53.3での構文検証。
- アプリ起動・同一ワークスペースだけのフォーカス、未知アプリ拒否のテスト。
- 一時HOMEでの設定配置・再実行・個人設定の保持、XDG設定先、日本語入力環境変数のテスト。
- GNOMEを切らずに別のHyprlandインスタンスを起動し、DMSとVicinaeの画面描画を確認。

検証用画面とログは、このマシンの `~/.cache/dotfiles-hyprland-proof/` に置いた。

未確認:

- 物理画面へログインした後のGPU動作、実キー操作、ロック解除・アイドル復帰、アプリごとの日本語入力、通話・画面共有。
- リモート接続の要件。GNOME Remote DesktopをHyprlandにも使える前提にはしない。GNOMEとHyprlandを同じユーザーで同時利用するリモート構成は、共有DBus/ユーザーサービスの扱いも含めて別途検証する。
- Ubuntu配布版が警告する `hyprland-guiutils` は現在のapt候補にない。セッション本体は起動できるが、一部のHyprland補助ダイアログは対象外。

## 追加した共通機能

共通テーマの正本は `desktop-themes/*/theme.json`。`python3 ~/.dotfiles/scripts/desktop-theme.py apply anime-blue` でGhostty・Hyprlandの枠色・DMS・Vicinae向け設定を生成する。初期テーマはAnime Blue。Ubuntuではログアウト中でも次回起動用の設定を準備できる。Vicinae 0.29のテーマファイルは `${XDG_DATA_HOME:-$HOME/.local/share}/vicinae/themes/` に配置する（[該当バージョンの検索処理](https://github.com/vicinaehq/vicinae/blob/v0.29.1/src/server/src/theme/theme-db.cpp)）。Hyprland内ではテーマ監視処理が反映と壁紙ローテーションを行う。テーマ選択は `Super+Ctrl+Alt+T`、次のテーマは `Super+Ctrl+Alt+N`、次の壁紙は `Super+Ctrl+Alt+W`。Ghosttyの既存ウィンドウは設定の再読み込みが必要な場合がある。

DMSバー右側に休憩タイマーとCodex使用量を追加した。それぞれクリックで詳細を開く。設定の再実行では初回だけバーへ追加し、その後の並び替え・無効化を保持する。

- 休憩タイマーは作業30分・休憩3分・スヌーズ3分。`Super+P` で開始／作業と休憩を切替、`Super+Shift+P` でスヌーズ、`Super+Ctrl+P` で停止。バーの詳細から各操作もできる。時間切れの後は手動開始が初期値。通知と音はHyprland内だけで実行し、状態はログアウトをまたいで保存する。保存した期限を過ぎて再ログインした場合は時間切れとして扱う。通知は重複を避ける方式のため、通知処理が異常終了した瞬間の通知は失われる場合がある。
- Codex使用量はローカルのセッション記録に残る直近のレート制限情報を60秒ごとに読む。二つの利用枠のうち残りが少ない割合を表示する。APIへの問い合わせは行わず、情報がないと `--`、古い記録には `stale` を表示する。会話本文や認証情報は出力しない。
- マイクは明示した機器名の優先順位を5秒ごとに確認する。初期値は空で現在の入力を維持する。`python3 ~/.dotfiles/scripts/ubuntu-mic-priority.py --list` で `node.name` を確認し、`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/mic-priority.json` の `preferred_sources` に上位から記載する。globが使える。`--once --dry-run` で切替候補を確認できる。

休憩時間等の個人設定は `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/break-timer.json`。これらのJSONは初回のみコピーし、再設定でも保持する。タイマー通知・マイク監視・テーマ監視はHyprlandセッションの子プロセスとして起動・終了する。GNOMEやシステムの定期実行agent、Home Assistant用サービスは変更しない。

追加機能のテストではテーマ生成・反映、タイマー遷移、マイク選択、使用量読み取り、設定の保持を一時ディレクトリと疑似コマンドで確認した。検証用HyprlandでDMSの両プラグイン読み込みとバー描画も確認済み。物理機器での音・通知・通話中のマイク切替、実ログイン時の表示と操作は次回確認する。天気表示やRaycastの個別拡張相当の作り込みは今後の対象。

参考: [ML4W](https://github.com/mylinuxforwork/dotfiles)の責務分割、[end-4](https://github.com/end-4/dots-hyprland)のcustom分離、[Caelestia](https://github.com/caelestia-dots/caelestia)の変数・override設計。各dotfiles全体の一括導入は行っていない。

## 実ログインでバーが表示されなかった場合の修正（2026-10-17）

GDMからの実ログインでDMS・VicinaeがX11表示の初期化待ちになり、壁紙だけになる状態を再現した。ネイティブシェル起動時だけ `DISPLAY` と `XAUTHORITY` を外す `hyprland-native.sh` を追加し、実セッションでバー表示とVicinaeのpingを確認した。Ghosttyも同じ経路で起動する。X11アプリ向けのセッション全体のDISPLAYは保持する。

GDMのPATHに `~/.local/bin` がなかったため、Hyprland設定で追加した。アプリ起動キーはCtrlではなく **Super（Windowsキー）+1/2/3**、ターミナルは **Super+Enter**。セッション終了時にGUI処理がTERMで止まらない場合は3秒後に子プロセスグループを終了し、起動ロックを解放する。

### アプリを開けない場合の実ログイン確認

通常の起動ではX11への接続が待ち続ける状態も確認した。Ghostty・Chrome・VS Codeのショートカットとdesktopエントリは `ubuntu-app-launch.sh` を共用する。Hyprland内ではGhosttyの単一インスタンス転送を無効にし、Chromium/Electronは `--ozone-platform=wayland` で起動する。GNOME内の実行では通常のバックエンドを使う。既存desktopエントリの名前・引数・ファイル受け渡しを保持し、最初の変更前に `.desktop.before-dotfiles-wayland` へバックアップする。

ユーザー領域に展開したVS Code tar版は、このUbuntuではsandbox helperの所有者／権限が適合せず異常終了した。公式のDebianパッケージ版を使う。既存の `~/.local/bin/code` が古いtar版を指す場合、setupは `/usr/bin/code` へのリンクに更新する。sandboxを無効化するフラグは使わない。既存のCode設定・拡張機能は保持する。

今回の実機検証では、Vicinaeの `app launch` からGhostty・Chrome・VS CodeがWaylandウィンドウとして表示されること、ショートカットと同じ起動スクリプトからChromeの起動とVS Codeへのフォーカスが動くことを確認した。公式VS Codeのクラス `com.microsoft.VSCode` にも対応する。独自の `Exec=env ...` 等は自動変換をスキップし、警告して既存設定を保持する。GNOMEの判定には現在のデスクトップ名も使い、残ったHyprland環境変数だけでは切り替えない。

ワークスペース循環は既存ワークスペースを対象にする `e-1/e+1` を使い、実セッションで9→1→9を確認した。GhosttyのSuper+t/rについても、検証用tmuxでUser0/User2の専用シーケンスが届くことを確認した。既存のGhosttyへ設定再読み込みを送り、稼働中のtmuxへ共通設定（set-titlesを含む）を反映済み。

## HHKBの物理キー配置

このマシンのHHKB Hybridには、`hypr/local.conf` のデバイス別設定で `kb_options = ctrl:swap_lwin_lctl` を適用した。HHKBは通常CapsLockがある位置のキーからLeft Ctrlを送るため、CapsLock用オプションではなくLeft CtrlとLeft Superを交換する。結果は「CapsLock相当の位置＝Super／Command」「左Windows／Command相当の位置＝Ctrl」。上記の操作表は交換後の論理キー名で読む。例: CapsLock相当の位置+1でGhostty、左Windows相当の位置+Oで次のワークスペース。

対象は `pfu-limited-hhkb-hybrid` とそのkeyboard/consumer-controlインターフェースに限定し、他のキーボードやGNOME側の割り当ては変更しない。マシンローカル設定はsetup再実行でも保持する。標準的なCapsLockを送る別キーボードでは別の割り当てが必要。XKBでキー変換を検証し、Hyprlandの実デバイスにオプションが反映されたことを確認済み。
