# 休憩タイマー

Hammerspoon が作業30分・休憩3分を管理し、SketchyBar に残り時間と開始待ちを表示します。

## キーボード操作

Ghostty にフォーカスがあるときだけ有効です。他のアプリでは通常のショートカットとして動作します。

| キー | 動作 |
| --- | --- |
| `⌘P` | `WORK ⌘P` 表示中は作業開始、`BREAK ⌘P` 表示中は休憩開始 |
| `⌘P` | 作業中は残り時間表示、休憩中は3分スヌーズ |
| `⌘O` | タイマーのON/OFF。ONに戻しても開始待ちになり、`⌘P`で開始 |

作業終了後は休憩の開始待ち、休憩終了後は次の作業の開始待ちになります。
通常の文字入力では開始しません。Hammerspoon の起動、設定の再読み込み、スリープ復帰後も作業の開始を待ちます。

作業中の `⌘P` は、画面下端に小さく「休憩まで 29:21」のように残り時間を表示します。絵文字や白い枠線は使わず、3秒で消えます。繰り返し押しても表示は重なりません。状態変更時の自動ポップアップは、従来どおり `alerts = false` で無効です。

## 音と設定

`config.lua` の `sounds = true` で音を有効にします。作業・休憩・スヌーズの残り60秒で短い「ピピ」、終了時に約5秒の音が鳴ります。1分以下のサイクルでは終了音だけ鳴ります。

音は LoFi Station の `lofi-web/public/sounds/` からコピーしたオリジナルの通知音です。

| 用途 | ファイル | 長さ |
| --- | --- | --- |
| 残り1分 | `sounds/warning-beep.mp3` | 約0.3秒 |
| タイマー終了 | `sounds/timer-complete.mp3` | 約5秒 |

ファイルは変換・編集せずにコピーしているため、LoFi Station と同じ音が鳴ります。dotfiles 内に保持するので、LoFi Station のチェックアウトがなくても動作します。

Mac の現在の出力先と音量を使い、ポップアップ通知の `alerts` 設定とは独立して再生します。`sound_volume` はシステム音量に対する0.0〜1.0の割合、`warning_seconds` は事前通知までの秒数です。

`sound_volume = 1.0` は現在のMacの音量をそのまま使います。音が小さい場合はMacの出力音量を上げてください。作業開始時や残り時間を表示する `⌘P` では音は鳴らず、残り1分と終了時だけ鳴ります。

`auto_start_work = false`、`auto_start_break = false` が手動開始の設定です。休憩を手動開始すると、休憩時間のカウントと星空表示がすぐに始まります。`auto_start_break = true` にした場合のみ、作業終了後に `fade_minutes` 分のフェードを経て休憩が自動開始します。

## 検証

```sh
lua scripts/test-break-timer.lua
luac -p hammerspoon/break_timer.lua break-timer/config.lua
```

実機で短い通知音を確認する場合:

```sh
hs -c 'return breaktimer.testSound("warning")'
```
