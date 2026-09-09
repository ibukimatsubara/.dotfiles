# SVUの自動サスペンドと遠隔復帰

## 目的

GPU搭載Ubuntuデスクトップ`svu`を、必要なときだけ起こす計算用ワーカーとして運用する。

- 60分間使われていなければdeep suspendへ移行する。
- 常時稼働するM1 MacBook Air `svm`からWi-Fiのmagic packetを送って復帰させる。
- 操作用Macでは`ssh-svu`の1コマンドでwakeとSSH接続を行う。
- 長時間の処理は`svu-run`で自動サスペンドから保護する。

Wi-Fiのパスワード、sudoパスワード、機器固有のMAC addressはGitへ保存しない。

## ファイル構成

```text
scripts/
├── setup-svu-power.sh
└── svu-power/
    ├── config.example
    ├── ssh-svu.sh
    ├── wake-svu.sh
    ├── svu-run.sh
    ├── svu-auto-suspend.sh
    ├── svu-auto-suspend.service
    ├── svu-auto-suspend.timer
    ├── svu-auto-suspend.default
    └── svu-auto-suspend.tmpfiles
```

## セットアップ

### 操作用Mac

```bash
cd ~/.dotfiles
./scripts/setup-svu-power.sh client
```

`~/.local/bin/ssh-svu`がdotfiles内のscriptへのsymlinkになる。SSH aliasは既定で`svu`と`svm`を
使う。異なるaliasを使う場合は`~/.config/svu-power/config`で変更する。

### Wake coordinatorのSVM

```bash
cd ~/.dotfiles
./scripts/setup-svu-power.sh coordinator
${EDITOR:-vi} ~/.config/svu-power/config
```

local configの`SVU_WAKE_MAC`へ`svu`のWi-Fi interfaceのMAC addressを設定する。通常の自宅LANが
`192.168.0.0/24`ではない場合は`SVU_WAKE_BROADCAST`も変更する。

### 計算用ワーカーのSVU

NetworkManager上の接続名を環境変数で渡してsetupする。

```bash
cd ~/.dotfiles
SVU_WIFI_CONNECTION='<Wi-Fi connection name>' ./scripts/setup-svu-power.sh worker
```

このsetupは次を行う。

- `/usr/local/sbin/svu-auto-suspend`と`/usr/local/bin/svu-run`をinstallする。
- systemdのserviceとtimerをinstallして有効化する。
- `/etc/default/svu-auto-suspend`へ60分とload thresholdの既定値を配置する。
- 指定されたWi-Fi profileでmagic-packet WoWLANを有効化する。

## 自動サスペンドの判定

timerは5分ごとに状態を確認する。次のいずれかがあれば最終活動時刻を更新する。

- login sessionまたは確立済みSSH接続がある。
- NVIDIA compute processがある。
- 1分load averageが`0.50`を超えている。
- `svu-run`で保護されたprocessがある。

すべてが60分間なければ`systemctl suspend`を実行する。復帰を検出した直後はidle時間をresetし、
すぐに再サスペンドしない。

## 日常の使い方

SVUへ接続する。

```bash
ssh-svu
```

眠らせたくない処理を実行する。

```bash
svu-run <command> [args...]
```

通常のCPUまたはGPU処理も自動検出される。network待ちなどで低負荷になる時間が長い処理には
`svu-run`を使う。

## 確認と停止

```bash
systemctl status svu-auto-suspend.timer
sudo /usr/local/sbin/svu-auto-suspend --status
journalctl -u svu-auto-suspend.service
```

自動サスペンドを止める場合は次を実行する。

```bash
sudo systemctl disable --now svu-auto-suspend.timer
```

## 制約

- `svm`が停止している場合は遠隔wakeできない。
- 通常のSSH packetだけではサスペンド中の`svu`を起こせないため、`ssh-svu`を使う。
- サスペンド中に実行時刻を迎える通常のcronやtimerは、それ自体では起動理由にならない。
- Wi-Fi router、SSID、subnetを変更した場合はWoWLANとbroadcast addressを再確認する。
- 現在の操作用Macを使わなくなった場合は、新しい操作端末でclient setupを実行する。
