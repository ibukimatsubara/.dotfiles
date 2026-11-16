# サンワダイレクト 400-MAWBT186 ペン型マウス

確認日: 2026-11-16。
Ubuntuでの識別・接続確認・左右クリック設定に使うための実機メモ。
macOSでレシーバー経由の入力復旧を確認した。
Ubuntuでもペンマウスが使えていることを利用者が確認済み。

## 実機のUSB識別情報

以下は付属の2.4GHzレシーバーをmacOS 26.7.1（25G241）で読み取った値。
レシーバーを抜くと該当するUSB・HIDデバイスだけが消えることを確認した。

| 項目 | 実測値 |
| --- | --- |
| 製品型番 | サンワダイレクト 400-MAWBT186 |
| USB製造元名 | `YICHIP` |
| USB製品名 | `Wireless Device` |
| Vendor ID | `0x3151`（10進数: `12625`） |
| Product ID | `0x3020`（10進数: `12320`） |
| Linuxで指定するVID:PID | `3151:3020` |
| USBデバイスのリリース番号 | `bcdDevice = 0x0002`（BCD表記: `0.02`） |
| USB仕様番号 | `bcdUSB = 0x0200`（USB 2.0） |
| 接続速度 | 12 Mb/s（Full Speed） |
| HIDマウス | Usage Page `1` / Usage `2` |
| HIDキーボード | Usage Page `1` / Usage `6`も登録される |

`bcdDevice`はUSBデバイスが申告するリリース番号であり、メーカーのファームウェア版数との対応は未確認。
ファームウェア本体の取得・更新は行っていない。
上記IDはUSBレシーバーの値であり、Bluetooth接続時の識別子は未確認。
`Wireless Device`や`3151:3020`だけで、この製品型番を一意に識別できるとは限らない。

## 接続・電源の仕様

- Bluetooth 5.2と2.4GHzワイヤレスに対応し、USB-AレシーバーとType-C変換アダプタが付属する。
- 本体とレシーバーのIDは固定で、レシーバー接続がBluetoothより優先される。
- Bluetoothへ切り替えるときは、レシーバーを抜いて本体の電源を入れ直す。
- Bluetoothの表示名は`BT5.2 Mouse`または`BT3.0 Mouse`。
  表示されない場合は、左・右・ホイール押し込みを同時長押しして再検出する。
- スリープからはボタン操作で復帰し、数秒かかる場合がある。

以上は[公式説明書 Ver1.1](https://www.sanwa.co.jp/support/setsumeisyo/download?file_name=400-MAWBT186_ver1-1.pdf)による。

赤点滅は電池残量低下、緑点灯は充電中、充電完了時は消灯する。
充電には付属またはUSB-A→USB-Cケーブルを使い、USB PD対応充電器は使わない。[公式説明書](https://www.sanwa.co.jp/support/setsumeisyo/download?file_name=400-MAWBT186_ver1-1.pdf)
充電しながら使用可能で、赤点滅の目安は残量40%以下と案内されている。[メーカーFAQ](https://direct.sanwa.co.jp/ItemPage/400-MAWBT186)

## 今回の接続不良と復旧

| 段階 | 確認結果 |
| --- | --- |
| 初期状態 | USBハブ3段経由でUSB列挙・HID登録とも成功。HID入力イベントは0件 |
| レシーバー抜去 | `3151:3020`と対応するHIDが消失。他のマウス・キーボードは残存 |
| ハブ2段目へ移設 | USB・HIDを再認識。約31秒の観測では入力イベント0件 |
| 本体OFF→ON・左ボタン操作を案内した後 | 利用者から動作復旧の報告。同じHIDサービスの入力イベントが0→2,763件へ増加 |

USB検出とHID登録まで進み、入力イベントが届いていない状態だった。
本体の復帰や無線接続の再確立が関係した可能性はあるが、復旧直前の具体的な操作は未確認で、原因は断定していない。
ハブ移設だけで直ったことや、本体直結での動作は確認していない。
当時、このMacには`BT5.2 Mouse` / `BT3.0 Mouse`の接続・登録がなく、別の機器へのBluetooth接続状況は未確認。

再発時は、本体の電源入れ直し・ボタンによる復帰・充電を確認し、レシーバーの本体直結と別ポートで比較する。
USB 3ハブなどをレシーバーから離すことも切り分けになる。[Appleの無線干渉対策](https://support.apple.com/ja-jp/102319)

## macOSで試した左右クリック設定

対象HIDに次のランタイム設定を行った。

```sh
hidutil property \
  --matching '{"VendorID":12625,"ProductID":12320,"PrimaryUsagePage":1,"PrimaryUsage":2}' \
  --set '{"HIDPointerButtonMode":2}'
```

設定値は`1`→`2`へ変わり、他のマウスは`1`のままだったが、実際の左右クリックは変わらなかった。
成功した設定として再利用しない。
試行後は対象の値を元の`1`へ戻した。
その後、macOS標準の「マウス」設定で`Secondary click: Click Left Side`から`Click Right Side`へ切り替えた。
設定画面の表示と、`defaults -currentHost read -g com.apple.mouse.swapLeftRightButton`が`0`であることを確認した。
この変更はKensingtonを含むマウス全体に適用される。
設定変更後のペンマウス実機での左右クリックは、利用者による確認待ち。

### Kensingtonだけを反転する追加設定

希望する構成は、ペンマウスを通常配置にし、KensingtonのUSBレシーバー`047d:80d6`だけ左右を反転するもの。
LinearMouseは利用方針に合わないため不採用とし、試行で追加したアプリはアンインストール、作成した設定はゴミ箱へ移した。
macOS標準設定は`Click Right Side`のままで、Kensingtonだけの反転は未完了。
追加の設定アプリを使わず、自作・最小構成で進める方針。
既存のHammerspoonで入力元を確実に識別できるかは未検証で、自作コードはまだ追加していない。
Ubuntuでは、後述の既存Hyprland設定と実機の入力イベントを確認するところから再開する。

## Ubuntuで確認する手順

### USB・入力デバイスを特定する

必要なコマンドのパッケージは`usbutils`、`libinput-tools`、`evtest`。
USB列挙と直近のカーネルログを確認する。

```sh
lsusb -d 3151:3020
sudo lsusb -v -d 3151:3020
sudo dmesg --ctime | tail -n 80
sudo libinput list-devices
```

レシーバーの抜き差しで消えるデバイスを確認し、そのポインタ用の`Kernel: /dev/input/eventN`を特定する。
同じレシーバーがキーボードとしても列挙され得るので、名前だけでイベントノードを選ばない。
特定したポインタ用ノードで、移動・各ボタン・ホイールを確認する。

```sh
# eventNは、上で確認したポインタ用の番号に置き換える。
sudo evtest /dev/input/eventN
```

各物理ボタンと`BTN_LEFT`・`BTN_RIGHT`・`BTN_MIDDLE`などの対応は、Ubuntu実機ではまだ計測していない。
右ボタン2個を個別に割り当てられるかも未確認。
`libinput list-devices`は既定値を表示するため、デスクトップで適用中の左右設定の確認には実際のクリックも使う。[Ubuntuのlibinputマニュアル](https://manpages.ubuntu.com/manpages/resolute/man1/libinput-list-devices.1.html)

### Hyprlandで左右を設定する

このリポジトリの[Hyprland設定](../platforms/ubuntu/hypr/hyprland.conf)はUbuntu 26.04 / Hyprland 0.53.xのHyprlang形式。
[入力設定](../platforms/ubuntu/hypr/conf/input.conf)には、すでに全体設定の`left_handed = true`がある。
ペンマウスのために全体設定を変更すると、Kensingtonにも影響する。

まずUbuntu実機でバージョンとデバイス名を確認する。

```sh
hyprctl version
hyprctl devices
```

ペンマウスだけ変更する場合は、ポインタ用の実際の名前で`device`設定を作る。
名前はmacOSの表示名から推測せず、抜き差し前後の`hyprctl devices`で確認する。
デバイス別設定は全体の`input`設定を上書きできる。[Hyprland 0.53のデバイス別設定](https://wiki.hypr.land/0.53.0/Configuring/Keywords/#per-device-input-configs)

```ini
# 記載例。nameはhyprctl devicesで確認したポインタ名に置き換える。
device {
    name = REPLACE_WITH_HYPRCTL_MOUSE_NAME
    left_handed = false
}
```

`false`は通常の左右配置、`true`は左右入れ替え。[Hyprland 0.53の入力オプション](https://wiki.hypr.land/0.53.0/Configuring/Variables/#input)
上の例は、既存の全体設定`true`に対してペンマウスだけ`false`へ戻す場合のもの。
`true`が希望なら現在の全体設定を継承できるため、同じ値を追加する必要はない。
適用後は左右クリック・ドラッグ・ホイールと、Kensingtonの従来の操作を実機で確認する。

### このマシンへ反映した設定

2026-11-16、Ubuntu上でUSB `3151:3020` とポインタ名 `yichip-wireless-device-mouse` を確認した。
[input.conf](../platforms/ubuntu/hypr/conf/input.conf)に次のデバイス別設定を追加し、`hyprctl reload` 後に設定エラーがないことを確認した。

```ini
device {
    name = yichip-wireless-device-mouse
    left_handed = false
}
```

全体の `left_handed = true` を保ち、ペンだけ通常の左右配置へ戻す。
設定反映後の物理ボタンの押し比べは利用者の確認待ち。
