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

通常の起動ではX11への接続が待ち続ける状態も確認した。Ghostty・Chrome・VS Codeのショートカットとdesktopエントリは `ubuntu-app-launch.sh` を共用する。Hyprland内ではGhosttyを `--gtk-single-instance=true` で起動し、既存プロセスから毎回新しいウィンドウを開く。Chromium/Electronは `--ozone-platform=wayland` で起動する。GNOME内の実行では通常のバックエンドを使う。既存desktopエントリの名前・引数・ファイル受け渡しを保持し、最初の変更前に `.desktop.before-dotfiles-wayland` へバックアップする。

Ghosttyの起動速度改善（2026-10-17）: 別プロセス起動ではウィンドウ表示まで約0.5秒、既存プロセスを共有する起動では約0.18秒を実測した。初回や最後のウィンドウを閉じて本体が終了した後は、通常どおり本体の起動時間がかかる。変更前から開いている別プロセスのウィンドウはそのまま使え、新方式で起動した本体を以降の起動で共有する。

ユーザー領域に展開したVS Code tar版は、このUbuntuではsandbox helperの所有者／権限が適合せず異常終了した。公式のDebianパッケージ版を使う。既存の `~/.local/bin/code` が古いtar版を指す場合、setupは `/usr/bin/code` へのリンクに更新する。sandboxを無効化するフラグは使わない。既存のCode設定・拡張機能は保持する。

今回の実機検証では、Vicinaeの `app launch` からGhostty・Chrome・VS CodeがWaylandウィンドウとして表示されること、ショートカットと同じ起動スクリプトからChromeの起動とVS Codeへのフォーカスが動くことを確認した。公式VS Codeのクラス `com.microsoft.VSCode` にも対応する。独自の `Exec=env ...` 等は自動変換をスキップし、警告して既存設定を保持する。GNOMEの判定には現在のデスクトップ名も使い、残ったHyprland環境変数だけでは切り替えない。

ワークスペース循環は既存ワークスペースを対象にする `e-1/e+1` を使い、実セッションで9→1→9を確認した。GhosttyのSuper+t/rについても、検証用tmuxでUser0/User2の専用シーケンスが届くことを確認した。既存のGhosttyへ設定再読み込みを送り、稼働中のtmuxへ共通設定（set-titlesを含む）を反映済み。

## HHKBの物理キー配置

このマシンのHHKB Hybridには、`hypr/local.conf` のデバイス別設定で `kb_options = ctrl:swap_lwin_lctl` を適用した。HHKBは通常CapsLockがある位置のキーからLeft Ctrlを送るため、CapsLock用オプションではなくLeft CtrlとLeft Superを交換する。結果は「CapsLock相当の位置＝Super／Command」「左Windows／Command相当の位置＝Ctrl」。上記の操作表は交換後の論理キー名で読む。例: CapsLock相当の位置+1でGhostty、左Windows相当の位置+Oで次のワークスペース。

対象は `pfu-limited-hhkb-hybrid` とそのkeyboard/consumer-controlインターフェースに限定し、他のキーボードやGNOME側の割り当ては変更しない。マシンローカル設定はsetup再実行でも保持する。標準的なCapsLockを送る別キーボードでは別の割り当てが必要。XKBでキー変換を検証し、Hyprlandの実デバイスにオプションが反映されたことを確認済み。

## Ubuntuの見た目をmacOSへ寄せる設定

macOSのテーマJSON・Ghostty設定・SketchyBar設定は維持し、追加の `ubuntu-style.json` と `ubuntu-ghostty.conf` を生成する。macOS向けの既存生成物は両プリセットで変更前とバイト単位で同じことを確認した。

- バーは左に休憩タイマーとワークスペース、中央にメディア、右にCodex使用量・CPU・メモリ・トレイ・通知・操作パネル・時計。重複するアプリ名とランチャーボタンを省く。
- 色・角丸・モジュール透明度・余白は共通プリセットから取得する。Anime Blueは全面の背景を透明にして、小さな角丸モジュールを上端へ配置する。非選択ワークスペースの背景は透明にする。
- UbuntuのGhosttyだけ `background-opacity = 0.78` を最後に読み込み、文字の濃さを維持する。macOSで無効にしているカーソルシェーダーをUbuntuでも無効にし、Ghosttyに対するHyprlandのblurも無効にする。

`desktop-theme.py apply NAME` で色と形状を反映する。既存のバー項目の並び順や追加ウィジェットは通常のテーマ変更では保持する。macOSに似せた並び順を明示的に採用する場合のみ、`python3 ~/.dotfiles/scripts/ubuntu-desktop-style.py --layout` を実行する。二つ目以降のバーは変更しない。

DMSの配列設定はIPC経由の変更に対応していないため、現在のIPCスナップショットへ対象項目だけをマージし、設定ファイルの監視機能で反映する。初回の前には `DankMaterialShell/settings.json.before-macos-style` を保存する。個人設定は引き続きリポジトリに含めない。

## Caelestia Shellへの切り替え

`~/.config/dotfiles/desktop-shell` に `caelestia` または `dms` を保存し、
`hyprland-session.sh` が選択したシェルを起動する。選択ファイルがない場合はDMS。
変更は `scripts/ubuntu-desktop-shell.sh select caelestia` で保存し、次回ログイン時に適用する。
戻す場合は `scripts/ubuntu-desktop-shell.sh select dms` を実行してログインし直す。
DMSの設定・プラグイン・パッケージは残す。

ランチャー・設定・通知・電源メニューの既存キーは選択中のシェルへ送る。
CaelestiaではSuper+SpaceとSuper+Shift+Spaceがランチャー、Super+commaがNexus設定、
Super+Nがサイドバー、Super+Yが壁紙設定も含むNexus、Super+Shift+Escapeが電源メニュー。
Super+Shift+Vのクリップボード履歴は引き続きVicinaeを使う。
アプリ起動・ウィンドウ移動・日本語入力・hypridle/hyprlockは既存の構成を使う。
Caelestia側の自動ロックは無効にし、二重のロック画面を避ける。
DMS専用の休憩タイマー表示はCaelestiaのバーには移植していない。
休憩タイマーの通知・キー操作と使用量収集は継続する。

Ubuntu 26.04 / Qt 6.10.2での実機導入はCaelestia Shell **v2.1.0**、CLI **v1.1.3**。
専用Quickshellは `2b4501a282689792b62e94f3fb30d8f512324fe6` をビルドし、
システムの `/usr/bin/qs` と分けて `~/.local/opt/caelestia` に配置した。
M3Shapesは `8a6fe8961749887d677700b6508e0c9249968b7e`、
libcavaは `LukashonakV/cava` の `f03278ef9e5e7948fb206453d2f02758f8db216c`。
ソースとビルドログは `~/.cache/dotfiles/caelestia-build`、QML本体は
`~/.config/quickshell/caelestia`。起動ヘルパーが専用のPATH・QML_IMPORT_PATH・
LD_LIBRARY_PATH・CAELESTIA_LIB_DIRを設定する。アイコンテーマはQS_ICON_THEMEで指定し、既定はYaru。

v2.5.0の設定画面はQt 6.10にないDoubleSpinBoxを使うため採用していない。
v2.1.0ではQt 6.10の予約語 `char` と衝突するQMLのIDだけを
`platforms/ubuntu/caelestia/qt-6.10.patch` で変更する。
`platforms/ubuntu/caelestia/hyprlock.patch` も適用し、Caelestia内のロック要求を既存の
`ubuntu-lock.sh` へ送る。ネイティブの `lock isLocked` IPCはhyprlockの状態を表さない。
再インストール時は展開したソースへ `patch -p1 < /path/to/qt-6.10.patch` を適用する。
libcavaのpkg-configにはヘッダーの親ディレクトリが含まれないため、ShellのCMake設定に
`-DCMAKE_CXX_FLAGS=-I$HOME/.local/opt/caelestia/include` も渡す。
Shellのインストール先は `INSTALL_LIBDIR=lib/caelestia`、
`INSTALL_QMLDIR=lib/qt6/qml`、`INSTALL_QSCONFDIR=$HOME/.config/quickshell/caelestia`。
既存のM3Shapesを使うため `ENABLE_MODULES=extras;plugin;shell` を指定する。

CaelestiaのJSON設定は初回だけコピーし、編集可能なファイルとして保持する。
CLIによる端末・GTK・Qt・ブラウザ等へのテーマ一括反映は無効にしている。
壁紙とShellの配色はCaelestiaが管理し、DMSのテーマ監視はCaelestia中には起動しない。
`ubuntu-theme.py` の手動テーマ変更・壁紙変更も選択中のシェルに合わせる。
設定のバックアップは `~/.local/state/dotfiles/backups/before-caelestia-*.tar.gz`、
セッションのログは `~/.local/state/dotfiles/hyprland-session.log`。

### Caelestiaの上バーとランチャー操作

`platforms/ubuntu/caelestia/modules/TopBars.qml` で横向きの上バーを構成する。
Caelestiaの配色・フォント・サービスを使い、左にワークスペース番号1〜9、右に
トレイ・音量・ネットワーク・通知・時計・電源を表示する。ウィンドウ名は表示しない。
標準の左バーは `bar.persistent=false` と `bar.showOnHover=false` で隠す。
番号の表示数は `bar.workspaces.shown` で設定する。
ランチャーのSuper+Jは次の候補、Super+Kは前の候補へ移動する。
この操作はランチャー内のQMLで処理し、他のアプリのキー割り当てには追加しない。

`bash scripts/setup-caelestia-overrides.sh` は互換性・hyprlock連携・上バー・
ランチャーキーのパッチを確認してから適用する。適用済みなら再適用しない。
上バーのソースは `~/.config/quickshell/caelestia/modules/dotfiles` から参照する。
`setup-desktop.sh` もCaelestiaがインストール済みならこの処理を実行する。
JSONの個人設定は引き続き `~/.config/caelestia/shell.json` に保持し、
上バー変更前の設定は `shell.json.before-topbar` に保存してある。

丸い外枠とドロワーは `topbar-frame.patch` で上バーの下へ移す。
上バーと外枠のオフセットは `modules/Layout.js` の `height`（既定44px）を共有する。
全画面表示ではオフセットを0に戻す。

ワークスペース番号の横には、そのワークスペースにあるウィンドウのアプリアイコンを
表示する。`bar.workspaces.showWindows` で表示を切り替え、`maxWindowIcons` で
各ワークスペースの上限を指定する（既定5、0なら制限なし）。

上バーにはCodexの残り利用枠、CPU・メモリ・システムSSDの使用率、天気を表示する。
Codexは既存の `scripts/codex-usage.py` からローカルの利用枠スナップショットを1分ごとに読み、
取得時刻・リセット時刻などはホバーで確認できる。CPU・メモリ・ストレージはCaelestiaのサービスを使う。
天気の場所は個人用JSONの `services.weatherLocation`（都市名または緯度,経度）、
摂氏表示は `services.useFahrenheit=false` で設定する。
Bluetoothボタンは表示せず、Vicinaeのトレイアイコンは `bar.tray.hiddenIcons` で隠す。

`topbar-no-top-edge.patch` で外枠の上辺の描画と予約スペースを0にする。
左右と下辺の厚さは維持し、右側のステータス表示はグレーに統一する。

Ctrl+QまたはSuper+Qでフォーカス中のウィンドウを閉じる。
ウィンドウ操作・ワークスペース切り替えは `bindp` でアプリのショートカット抑制を回避する。
scrcpyのウィンドウを閉じてもAndroidエミュレーター本体は停止しない。

GhosttyのUbuntu用背景は `ghostty-monochrome.conf` をテーマより後に読み、黒の半透明にする。
Caelestiaの白黒配色は `caelestia scheme set -n dynamic -v monochrome -m dark`。
配色の選択はCaelestiaの個人用stateに保存される。

Ghosttyの背景ぼかしはHyprland側で適用する。テーマ生成時のGhosttyルールは `no_blur off`。

左端はCaelestiaロゴ、その右にPomoruの残り時間を表示する。作業中は単色トマト、休憩中はコーヒーカップ。作業は紫、休憩はグレー。
`modules/PomoruStatus.qml` が `$XDG_CACHE_HOME/pomoru/status.json` を読み込む。
一時停止は残り時間の停止として反映する（Pomoru v1.2.0は一時停止フラグを出力しない）。
終了時は表示を隠し、異常終了でファイルが残った場合もプロセス確認で5秒以内に隠す。

### Pomoruの導入と操作

音付きカスタム版は `bash scripts/install-pomoru.sh` で導入する。
Rust/Cargo と FFmpeg の `ffplay` が必要。上流 v1.2.0 のソースをコミットとSHA256で固定し、
ローカルパッチ適用後にテスト・リリースビルドして `~/.local/bin/pomoru` に配置する。
既存バイナリは `~/.local/bin/pomoru.upstream` に初回のみ退避する。

作業・短い休憩・長い休憩の残り1分で Lofi Station の `warning-beep.mp3`、
終了時に `timer-complete.mp3` を再生する。一時停止中には鳴らさない。
通知は `Pomoru · Work` / `Pomoru · Break` と短い本文に統一する。
通知文と音源パスは `~/.config/pomoru/alerts.toml` で変更でき、再起動で反映する。
音源は同ディレクトリの `sounds/` に配置するため、Lofi Station の起動は不要。
再導入手順と検証は [Pomoruカスタム版](../platforms/ubuntu/pomoru/README.md) を参照。

起動は `pomoru`。Spaceで開始・一時停止、Tabで停止中のセッション変更、qで終了。
旧Bahaaio/pomoは使用しない。

`setup-desktop.sh` が `platforms/ubuntu/pomoru/` の設定を初回だけコピーする。
作業50分、短い休憩10分、長い休憩30分。作業3回ごとに長い休憩を挟む。
終了時は次のセッションへ切り替えて待機し、Spaceで開始する。
タイマー画面の `a` で次のセッションの自動開始を切り替えられる。
配色は黒・グレーと紫。タスクを含む実際の個人設定は上書きせず、リポジトリへ保存しない。
設定は `~/.config/pomoru/config.toml`、配色は `~/.cache/pomoru/colors.json`。
キャッシュを削除した場合は `setup-desktop.sh` で配色を再作成できる。

上バーは `bash scripts/setup-caelestia-overrides.sh` を実行後、Caelestiaを再起動して反映する。
状態JSONは更新中に一瞬空になるため、読み取り失敗時は直前の正常値を保持する。
数字には等幅フォントと固定幅を使い、秒数の更新で位置が動かないようにする。
トマトは `TomatoIcon.qml` で描画し、絵文字やSVGプラグインを必要としない。

フォーカス枠の紫は個人用 `~/.config/hypr/local.conf` で以下を指定する。

```ini
general {
    col.active_border = rgb(b49cde)
}
```

### Space 1 のログイン時配置

Hyprland にログインすると `scripts/hyprland-workspace-one.py` が pomoru、
cliamp（`music-player.sh` の Music プレイリスト）、Chrome アプリ表示の
Notion Calendar（`https://calendar.notion.com`、既定プロファイル）を開く。
右半分をカレンダー、左上を pomoru、左下を cliamp にして通常のタイルとして配置する。
タイマー開始や音楽再生の操作は各アプリ側で行う。

既存の対象ウィンドウを再利用し、3つとも Space 1 にあれば現在の配置を維持する。
起動待ちは最大60秒。失敗した場合は起動済みのウィンドウを残し、セッションのログへエラーを出す。
手動で不足分を開き直す場合は次を実行する。

```bash
python3 ~/.dotfiles/scripts/hyprland-workspace-one.py
```

自動起動を止める場合は `scripts/hyprland-session.sh` の
`spawn python3 "$scripts_dir/hyprland-workspace-one.py"` を外す。

### デスクトップシェルの自動復旧

Caelestia / DMS は独立した systemd ユーザーサービス
`dotfiles-desktop-shell@<HyprlandのセッションID>.service` で管理する。
`hyprland-session.sh` はサービスを開始するだけで、監視の親にはならない。
セッション補助プロセスが終了してもデスクトップの監視は継続する。

サービス内の `ubuntu-desktop-watch.py` がシェルの終了後2秒で再起動し、
短時間の終了が続けば待ち時間を最大30秒まで延ばす。
監視自体が終了した場合も systemd の `Restart=always` で3秒後に復旧する。
Hyprland の生存はセッションのロックファイルから得た PID の pidfd で確認し、
一時的な IPC の失敗や応答遅延ではセッション終了と判定しない。
Hyprland の終了後はシェルを停止し、サービスの ExecCondition が再起動を止める。
セッションごとのロックで監視の重複起動を防ぐ。

再起動履歴は `~/.local/state/dotfiles/desktop-shell-watch.log`
（`XDG_STATE_HOME` 指定時はその配下）に保存する。終了シグナルも記録する。
詳細ログは `journalctl --user -u 'dotfiles-desktop-shell@*'`、
Quickshell 自体のログは `$XDG_RUNTIME_DIR/quickshell/by-id/` 配下で確認できる。
監視自体の強制終了からの復旧は実機で確認済み。クラッシュ原因の解消とは別。

導入・現在のセッションでの開始:

```bash
./platforms/ubuntu/setup-desktop.sh
systemctl --user daemon-reload
systemctl --user start "dotfiles-desktop-shell@${HYPRLAND_INSTANCE_SIGNATURE}.service"
```

### Ghostty のプロセス分離

Ubuntu の `ubuntu-app-launch.sh` は新しい Ghostty を
`--gtk-single-instance=false` で起動する。既存プロセスの新規ウィンドウで
発生した描画崩れを切り分けるため、単一プロセスの共有を一旦やめる。
既存ウィンドウのプロセスは変更しない。

### バー中央の再生中の曲

Caelestia の独自トップバーは `modules/NowPlaying.qml` で、ジャケット・曲名・
アーティストを中央に表示する。Caelestia の MPRIS サービスを使い、
再生中のプレイヤーを優先する。cliamp や Chrome など MPRIS 対応アプリが対象。
クリックで再生・一時停止、ホバーで曲名全文を表示する。
画像が取得できなければ macOS の SketchyBar と共通のプレースホルダー画像を使う。
再生ボタンは表示しない。曲情報がなければ非表示。
左右の項目と重ならないよう幅を制限し、空きが少ない画面では非表示にする。
