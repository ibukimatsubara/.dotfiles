# Ubuntu / Hyprland の Voxtype 音声入力

2026-10-18 時点の構成。OpenWhispr から Voxtype へ移行し、設定と辞書の復元用ファイルを
`platforms/ubuntu/voxtype/` に保存している。ストリーミングは日本語で安定しなかったため、
現在は GPU モデル常駐と一括認識・貼り付けを組み合わせて使う。

## 現在の設定

| 項目 | 設定 |
| --- | --- |
| Voxtype | v1.1.1、Linux x86_64 Vulkan バイナリ |
| GPU | NVIDIA RTX 2060 6 GB、Vulkan バックエンド |
| モデル | Whisper `large-v3-turbo`、モデル名で指定 |
| 言語 | 日本語固定 `ja`、英語への翻訳は無効 |
| マイク | DJI MIC MINI、PipeWire 経由の ALSA PCM `voxtype_dji` |
| 操作 | Shift+Space で録音開始・停止を切り替え、Esc で録音・認識を破棄 |
| 起動 | `voxtype.service` をユーザーの `default.target` で自動起動 |
| モデル読み込み | 起動時に読み込み、常駐させる |
| ストリーミング | 無効。録音停止後に一括認識・貼り付け |
| 出力 | クリップボード + Ctrl+Shift+V |
| 自動送信 | 無効。送信操作は手動 |
| 通知 | 録音開始・停止、認識完了、音声なしを通知 |
| 録音状態 | Caelestia の workspace 番号の右に表示 |

GPU は実際に使用中。直近の日本語では、約 7 秒の音声の認識に約 1.2 秒かかった。
モデルは起動時に読み込んで常駐させ、以前の録音ごとの読み直しを省く。
GPU メモリはモデル読み込み直後に約 1.5 GB 使用していた。
認識時間は音声や他の処理の負荷で変わる。録音自体の上限は 60 秒。

## 復元用ファイル

| リポジトリ内 | 復元先 | 内容 |
| --- | --- | --- |
| `platforms/ubuntu/voxtype/config.toml` | `~/.config/voxtype/config.toml` | モデル、言語、ストリーミング、出力、通知、辞書 |
| `platforms/ubuntu/voxtype/voxtype.service` | `~/.config/systemd/user/voxtype.service` | ログイン時の自動起動 |
| `platforms/ubuntu/voxtype/dji-mic.conf` | `~/.asoundrc` にブロックを取り込む | DJI 用の PipeWire PCM |
| `platforms/ubuntu/caelestia/modules/VoxtypeStatus.qml` | Caelestia override から参照 | バーの録音時間と処理状態 |
| `platforms/ubuntu/caelestia/voxtype-notifications.patch` | `services/NotifData.qml` へ適用 | 同じ通知 ID を更新した場合の再表示 |

モデル本体とバイナリは Git に入れない。モデルは約 1.62 GB で、通常は
`~/.local/share/voxtype/models/ggml-large-v3-turbo.bin` に置く。
`config.toml` はユーザー名を含む絶対パスを使わず、`model="large-v3-turbo"` で解決する。
ユーザーサービスは `%h` と `%t` を使うので、ユーザー名や UID を固定していない。

設定ファイルは復元用のコピー。手元の設定や辞書を変更したら、リポジトリ側にも反映する。
このフォルダーを root の `setup.sh` が自動で導入するわけではない。

## 別の Ubuntu マシンへ導入する

### 1. 依存と GPU

```bash
sudo apt install wtype wl-clipboard pipewire-alsa libnotify-bin libvulkan1 vulkan-tools
nvidia-smi
vulkaninfo --summary
```

現在のマシンは NVIDIA ドライバー 595.99.02 で動作確認済み。
別のマシンでは、その Ubuntu と GPU に対応したドライバーを先に導入する。

### 2. Voxtype バイナリ

[公式 v1.1.1 リリース](https://github.com/peteonrails/voxtype/releases/tag/v1.1.1) の Vulkan 版を使用する。

```bash
voxtype_install_dir="$HOME/.local/opt/voxtype/1.1.1"
mkdir -p "$voxtype_install_dir" "$HOME/.local/bin"
curl --fail --location \
  https://github.com/peteonrails/voxtype/releases/download/v1.1.1/voxtype-1.1.1-linux-x86_64-vulkan \
  --output "$voxtype_install_dir/voxtype-vulkan"
printf '102a7caa22facc5c257c526ae4a9e63c04c027297fec4ca370209a1f94ae9863  %s\n' \
  "$voxtype_install_dir/voxtype-vulkan" | sha256sum --check -
chmod +x "$voxtype_install_dir/voxtype-vulkan"
ln -sfn "$voxtype_install_dir/voxtype-vulkan" "$HOME/.local/bin/voxtype"
```

### 3. モデル

```bash
"$HOME/.local/bin/voxtype" setup model
```

選択画面で多言語版の `large-v3-turbo` をダウンロードする。`.en` は英語専用なので選ばない。
既存のモデルを移す場合は、上記のモデル保存先へ配置する。
今回の移行では OpenWhispr 側のモデルから作成したハードリンクを使用しており、
OpenWhispr のアプリ削除後も Voxtype 側のファイルが残ることを確認している。

### 4. DJI マイク

`dji-mic.conf` の `pcm.voxtype_dji` ブロックを `~/.asoundrc` に一つだけ入れる。
既存の ALSA 設定がある場合は、このブロックを取り込んで他の設定を保持する。
`~/.asoundrc` がなければ、次のコピーでよい。

```bash
cp "$HOME/.dotfiles/platforms/ubuntu/voxtype/dji-mic.conf" "$HOME/.asoundrc"
```

`capture_node` は DJI MIC MINI の安定した PipeWire ノード名を指定している。
別のマイクや個体では `wpctl status` と `wpctl inspect <source-id>` で `node.name` を確認し、
この値を変更する。数値の source ID はログインや再接続で変わるので設定に保存しない。

直接の `plughw:CARD=MINI,DEV=0` は Voxtype のデバイス探索で二重オープンできずに
失敗したため使用しない。PipeWire PCM は共有入力を使える。

### 5. 設定とログイン時の自動起動

既存の設定とサービスがある場合は先にバックアップしてからコピーする。

```bash
mkdir -p "$HOME/.config/voxtype" "$HOME/.config/systemd/user"
cp "$HOME/.dotfiles/platforms/ubuntu/voxtype/config.toml" "$HOME/.config/voxtype/config.toml"
cp "$HOME/.dotfiles/platforms/ubuntu/voxtype/voxtype.service" "$HOME/.config/systemd/user/voxtype.service"
systemctl --user daemon-reload
systemctl --user enable --now voxtype.service
```

起動時に Wayland のソケットがまだなければ、5 秒後に再試行する。
`.dotfiles/scripts/hyprland-session.sh` が `WAYLAND_DISPLAY` と PATH などを
`dbus-update-activation-environment --systemd` でユーザーサービスへ渡す。
この環境では `graphical-session.target` が active にならないため、`default.target` を使用する。

### 6. Shift+Space

`~/.config/hypr/local.conf` に一つだけ登録する。

```ini
bind = SHIFT, Space, exec, ~/.local/bin/voxtype record toggle
```

開始・停止は Hyprland 側の toggle を使う。
他のアプリや IME が同じ Shift+Space を奪っていないかも確認する。

### Esc でキャンセル

`hotkey.cancel_key="ESC"` で、録音中または認識中に Esc を押すと結果を破棄する。
`cancel_key` は Voxtype 内蔵のキー監視 (evdev) でしか効かないため `hotkey.enabled=true` にしている。
開始・停止キー `hotkey.key` は普段押さない `F24` にして、Shift+Space と二重に切り替わらないようにする。
ユーザーが `input` グループに入っている必要がある (`id` で確認し、追加後は再ログイン)。

evdev はキーを横取りしないので、Esc はフォーカス中のアプリにも届く。
待機中の Esc は何もしない。ydotool などの仮想キーボードは監視対象外なので、確認は実キーで行う。

### 7. Caelestia

```bash
bash "$HOME/.dotfiles/scripts/setup-caelestia-overrides.sh"
systemctl --user restart "dotfiles-desktop-shell@${HYPRLAND_INSTANCE_SIGNATURE}.service"
```

録音中・streaming 中はマイクと `REC mm:ss`、認識中は `Processing…`、待機中は非表示。
バーの字体・間隔・白黒配色を使い、数字の幅を固定している。

通知先は Caelestia / Quickshell。Xfce が通知を受け取る場合は競合するサービスを停止する。

```bash
systemctl --user mask --now xfce4-notifyd.service
busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications \
  org.freedesktop.Notifications GetServerInformation
```

サーバー名が `quickshell` になることを確認する。
Caelestia の `utilities.toasts.kbLayoutChanged=false` は、貼り付け用 wtype の仮想キーボードが
接続・切断するたびに「Keyboard layout changed」が出るのを防ぐ。
通常のアプリ通知と Voxtype の録音通知は有効なまま。
`voxtype-notifications.patch` は、一度消えた Voxtype 通知が同じ ID で更新されたときに
再表示し、タイマーも再開する。DND 設定には従う。

## 辞書と入力方式

`whisper.initial_prompt` に GitHub、Issue、PR、.dotfiles、Codex、Hyprland、Caelestia、
Voxtype、OpenWhispr、DJI MIC MINI など19用語のヒントを登録している。
`text.replacements` には10件の置換があり、たとえば次を補正する。

- `一周を作成しておいてください` → `Issueを作成しておいてください`
- `open whisper` → `OpenWhispr`
- `vox type` → `Voxtype`
- `hyperland` → `Hyprland`

日本語の語境界やストリーミングのチャンクをまたぐフレーズでは、置換が効かないことがある。
認識ヒントも表記を保証するものではない。「公園を一周」などを壊さないよう、
`一周` 単体を一律に置換するルールは登録していない。

出力は `paste` と Ctrl+Shift+V。直接の `type` は日本語の文字が欠けたため変更した。
Ghostty は Shift+Insert を貼り付けに割り当てておらず、Ctrl+Shift+V が正しい設定だった。
元のクリップボードを復元し、復元待ちは動作確認済みの 1000 ms とする。
自動 Enter は `output.auto_submit=false`。`text.smart_auto_submit` も既定の無効のまま使う。

## 確認と切り戻し

```bash
systemctl --user is-enabled voxtype.service
systemctl --user status voxtype.service
voxtype info devices
voxtype status
journalctl --user -u voxtype.service -n 100 --no-pager
nvidia-smi
```

ログの `using Vulkan0 backend`、`Model loaded, ready for voice input` を確認する。
起動直後からモデルが読み込まれ、録音開始後の状態ファイルが `recording` になる構成。
入力・認識結果をログに含むため、他の人へ共有するときは必要な行だけを取り出す。

後から実験的な設定を試して一括入力へ戻す場合は、次で復元できる。

```bash
voxtype config set whisper.streaming false
voxtype config set output.restore_clipboard_delay_ms 1000
systemctl --user restart voxtype.service
```

モデル常駐は維持する。GPU メモリを空ける必要がある場合は、streaming が無効な状態で
`voxtype config set whisper.on_demand_loading true` を設定して再起動する。
設定変更前のバックアップは `~/.local/state/voxtype/backups/` にある。

### ストリーミングの試行と切り戻し

v1.1.1 で `whisper.streaming=true`、モデル常駐、1.2 秒間隔、8 秒の音声窓を試した。
確定チャンクを辞書へ通すため `streaming.type_partials=false`、逐次書き直しは
`revision_mode=false` にしたが、日本語入力が出ないという実使用上の問題があり無効へ戻した。

実際のログでは推論が約 2〜2.6 秒かかり、処理間隔 1.2 秒を超える警告が出ていた。
実装には連続した推論結果の安定待ちもあり、これらが部分出力の遅れにつながる。
この環境で実用的な日本語のリアルタイム入力は確認できていないため、復元用設定も
`streaming=false` にする。

Flash Attention も比較した。同じ 8 秒の公開サンプルを日本語設定で処理した場合、
無効は約 2.03 秒、有効は約 2.87 秒だったため、有効化していない。
サンプルの英語認識では 6 秒を約 0.56 秒で処理できたが、日本語入力の streaming 間隔を
決める基準には不十分だった。

## OpenWhispr からの移行

OpenWhispr 1.10.3 の `open-whispr` パッケージは削除済み。
ユーザーの自動起動 `~/.config/autostart/open-whispr.desktop` と、Hyprland の
`openwhispr-binds.conf` の読み込みも取り除く。
Voxtype のモデルは専用の保存先にあり、OpenWhispr のインストールを必要としない。

参照: [Voxtype v1.1.1 設定仕様](https://github.com/peteonrails/voxtype/blob/v1.1.1/docs/CONFIGURATION.md)、
[streaming の出力経路](https://github.com/peteonrails/voxtype/blob/v1.1.1/src/output/streaming.rs)。
