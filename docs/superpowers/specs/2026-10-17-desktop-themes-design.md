# Desktop themes

## Intent

既存の Ghostty、SketchyBar、壁紙をひとつのテーマとして保存し、キーボードでまとめて切り替える。現在の暖色の見た目を `walnut` として残し、読みやすさを優先した `anime-blue` を追加する。

## Design

- `desktop-themes/<name>/theme.json` に表示名、Ghostty 設定、SketchyBar の配色と寸法、壁紙の URL と SHA-256 を保存する。
- `scripts/desktop-theme.sh` を CLI とし、Python 標準ライブラリで検証、壁紙の取得、設定生成を行う。追加の常駐プロセスは作らない。
- 生成物は `~/.config/desktop-theme/generations/` に保存し、検証と取得が完了してから `current` シンボリックリンクを atomic に切り替える。失敗時は選択中のテーマを維持する。
- Ghostty は optional include、SketchyBar は生成済みの色と寸法を読み込む。未選択時は従来の見た目を使う。ナビゲーション、コピー、タイマーの設定は共通のままとする。
- Hammerspoon は現在のテーマの壁紙だけを毎時切り替える。旧壁紙モジュールの画面別画像選択は、テーマ未選択時のフォールバックとして残す。
- Hammerspoon の chooser を `Ctrl+Option+Cmd+T`、次のテーマを `Ctrl+Option+Cmd+N`、次の壁紙を `Ctrl+Option+Cmd+W` に割り当てる。設定全体を再起動せず反映する。
- CLI は `list`、`current`、`apply NAME`、`next`、`pick`、`wallpaper` を提供する。`pick` の CLI 選択画面は fzf を使う。
- 壁紙画像と生成物は Git に含めず、出典とハッシュを管理する。既存の画像キャッシュはハッシュ一致時に再利用する。

## Presets

- `walnut`: 現在の暖色のバー、GitHub Dark、透過率 0.78、実写風景 2 枚。
- `anime-blue`: 青系のバー、TokyoNight Storm、透過率 0.94、海沿いの踏切。バーは上端に密着した左・中央・右の 3 ブロックに分け、逆角丸でつなぐ。画面全体を同色の 4pt の枠で囲み、画面下の左右も半径 18pt の逆角丸にする。左端の丸アイコンは表示しない。細かい物の多い部屋の画像は含めない。
- 分割ブロックの逆角丸は生成した画像を SketchyBar の項目に載せ、幅の変化に追従させる。画面端の枠と逆角丸は Hammerspoon が描画し、クリック・ドラッグを通過させる。画面構成・Space の変更に追従し、ネイティブのフルスクリーンでは非表示にする。

## Validation

実際の一時ディレクトリで生成、テーマの循環、入力拒否、破損画像、取得失敗を検証する。Lua ではテーマ内の壁紙選択と従来の画面別選択を確認する。実機では両テーマを往復し、Ghostty の設定検証、バーの読み込み、壁紙 URL、ショートカットの登録を確認する。
