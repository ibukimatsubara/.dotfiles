# Desktop themes

Ghostty・SketchyBar・デスクトップ壁紙をまとめて切り替える。キーバインド、コピー、ウィンドウ移動、休憩タイマーは共通設定として維持する。

## 操作

| ショートカット | 動作 |
| --- | --- |
| `Ctrl+Option+Cmd+T` | テーマ一覧を開く。文字で検索し、Enter で適用、Esc で閉じる |
| `Ctrl+Option+Cmd+N` | 次のテーマへ。最後のテーマから最初に戻る |
| `Ctrl+Option+Cmd+W` | 現在のテーマ内で次の壁紙へ |

Hammerspoon が起動しており、アクセシビリティ権限が必要。キー操作はどのアプリからでも使用できる。

ターミナルでは次のコマンドを使う。既に開いているシェルには `source ~/.dotfiles/zsh/configs/desktop-theme.zsh` で関数を追加する。

```bash
desktop-theme                    # fzf で選択
desktop-theme list
desktop-theme current
desktop-theme apply anime-blue
desktop-theme apply walnut
desktop-theme next
desktop-theme wallpaper
```

シェル関数を使わない場合は `~/.dotfiles/scripts/desktop-theme.sh` に同じ引数を渡す。Python 3 が必要で、ターミナルの選択画面だけは fzf も使う。Hammerspoon の選択画面には fzf は不要。

## 同梱テーマ

- **walnut**: 元の暖色のガラス風バー、GitHub Dark、Ghostty 透過率 0.78。山の湖と夕景の実写写真。
- **anime-blue**: 左・中央・右の 3 ブロックに分けた青系のバー。各ブロックは上端に逆角丸でつながり、間の透明な領域には壁紙が見える。画面全体を同色の 4pt の枠で囲み、上下の左右は半径 18pt の逆角丸でつなげる。TokyoNight Storm、Ghostty 透過率 0.94。3840×2160 の海沿いの踏切。文字が壁紙に埋もれにくい設定。壁紙は現在 1 枚なので、自動切替でも同じ画像を維持する。

壁紙は毎時、選択中のテーマに登録された画像だけから選ぶ。複数画面にも適用し、画面構成が変わった際も再適用する。元画像をそのまま使い、画面比率の調整は macOS に任せる。

## 別の Mac で使う

通常の `./install.sh` と `./setup.sh` で Ghostty、SketchyBar、Hammerspoon の設定をリンクしたあと、テーマを選ぶ。

```bash
~/.dotfiles/scripts/desktop-theme.sh apply anime-blue
```

初回は登録済みの配布元から壁紙を取得し、SHA-256 を確認する。既存のローカルキャッシュが一致すれば再利用する。キャッシュ取得後はオフラインでも切り替えられる。

```bash
desktop-theme apply anime-blue --offline
```

設定は直ちに再読込する。Hammerspoon の設定を新規追加した直後は、一度 Hammerspoon を再読込してショートカットを登録する。テーマ切替時に Hammerspoon 全体を再起動することはなく、作業タイマーを維持する。

## テーマを追加・編集する

`desktop-themes/<name>/theme.json` を追加する。テーマ名は英小文字・数字・ハイフン。

- `label`, `description`: 選択画面に出す名前と説明。
- `ghostty`: 配色、背景透過率、ブラー。許可するキーは `scripts/desktop-theme.py` の検証処理を参照。
- `colors`: SketchyBar の `TEXT_COLOR`, `FOCUS_COLOR` などの色。形式は `0xAARRGGBB`。JankyBorders 起動中はフォーカス枠色も反映する。
- `style`: バーの高さ、角丸、余白、ブラー。既存テーマと同じ変数名で指定する。`BAR_ATTACHED: 1` と `BAR_MARGIN: 0`・`BAR_Y_OFFSET: 0` で上・左右に密着させる。`BAR_SECTIONS: 1` は左・中央・右に背景を分け、`0` または省略で一枚につなげる。中央の再生情報は従来どおり再生中だけ表示する。`BAR_INVERSE_RADIUS` は各ブロック上端と画面外側下端の逆角丸の半径。ブロック間は SketchyBar の画像、画面端は Hammerspoon で描画する。画面構成・テーマ変更に追従し、ネイティブのフルスクリーンでは非表示になる。
- `rotation_seconds`: 自動切替の間隔。60 秒以上。
- `wallpapers`: `id`, `filename`, `url`, `source`, `sha256`。URL は HTTPS。`local_candidates` は既存画像を再利用するためのホームディレクトリからの相対パス。

変更後は `desktop-theme apply <name>` で再適用する。プリセットには見た目だけを入れ、共通のキー設定は各アプリの設定ファイルに置く。

`style` の `BAR_SHOW_BRAND: 0` で左端の丸アイコンを非表示にする。省略または `1` で表示する。

`SCREEN_BOTTOM_RADIUS: 18` で画面の左下・右下にも半径 18pt の逆角丸を表示する。`DARK_COLOR` を使用し、`0` または省略で非表示。画面構成・テーマ変更に追従し、ネイティブのフルスクリーンでは上側と一緒に非表示になる。

`SCREEN_BORDER_WIDTH: 4` で画面の周囲に 4pt の枠を表示する。色は `DARK_COLOR`。上下の逆角丸は枠の内側へつながる。`0` または省略で枠を非表示にする。枠はクリックやドラッグを妨げず、ネイティブのフルスクリーンでは非表示になる。

## 保存先と失敗時の動作

- 管理する定義: `~/.dotfiles/desktop-themes/`
- 取得した画像: `~/Pictures/Wallpapers/themes/<name>/`
- 生成した設定: `~/.config/desktop-theme/generations/`
- 選択中の生成物へのリンク: `~/.config/desktop-theme/current`

全画像の取得と検証、設定生成が成功してからリンクを切り替える。不正な値、通信失敗、ハッシュ不一致では選択中の設定を維持する。画像と生成物はリポジトリ外に保存する。

テーマ未選択時は Ghostty・SketchyBar の従来の見た目と、`hammerspoon/wallpaper.lua` の旧画面別画像選択にフォールバックする。

## 壁紙の出典

- Alpine lake: [Elias Tigiser / Pexels](https://www.pexels.com/photo/lake-beside-mountain-14786072/)
- Rio Grande sunset: [Kyle Glenn / Unsplash](https://unsplash.com/photos/landscape-photography-of-river-leading-to-mountain-0JJzYdoq62c)
- Anime seaside railway: [dharmx/walls の収集画像](https://github.com/dharmx/walls/blob/main/anime/a_train_crossing_with_a_train_track_and_a_body_of_water.png)。収集リポジトリの管理者を原作者として扱わない。

各画像は配布元・原作者の利用条件に従う。画像自体をこの dotfiles へ転載しない。

設計上の参考: [nicknisi/dotfiles](https://github.com/nicknisi/dotfiles#themes)、[slashspace/dotfiles](https://github.com/slashspace/dotfiles#theme-workflow)。実装はこのリポジトリの既存設定に合わせて作成した。
