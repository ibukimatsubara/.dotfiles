# Desktop wallpapers

## フリーレン / 青い花畑と星空

2026-10-18 に Ubuntu / Caelestia で選択していた壁紙。別のマシンでも使えるよう、配布元と取得手順を記録する。

| 項目 | 内容 |
| --- | --- |
| 作品 | 葬送のフリーレン |
| 作者 | むぐ煮（配布ページの Artist 表記） |
| 配布ページ | [Wallpaper Abyss / Alpha Coders: 1354384](https://wall.alphacoders.com/big.php?i=1354384) |
| 元画像 | [1354384.png](https://images8.alphacoders.com/135/1354384.png) |
| 解像度・形式 | 3840×2160（4K・16:9）、PNG |
| SHA-256 | `d2765e65e04ee2d1395a00621757eedfa505ea327032b1bb101d82b4dda2cb6a` |

### 別のマシンで取得する

macOS / Ubuntu 共通。画像はリポジトリ外に保存する。

```bash
mkdir -p "$HOME/Pictures/Wallpapers/gallery/images"
curl --fail --location --retry 3 \
  'https://images8.alphacoders.com/135/1354384.png' \
  --output "$HOME/Pictures/Wallpapers/gallery/images/1354384.png"
shasum -a 256 "$HOME/Pictures/Wallpapers/gallery/images/1354384.png"
```

SHA-256 が上記の値と一致することを確認する。Ubuntu / Caelestia が起動している場合は、次のコマンドで設定できる。

```bash
caelestia wallpaper -f "$HOME/Pictures/Wallpapers/gallery/images/1354384.png"
```

macOS や他のデスクトップ環境では、保存した PNG をその環境の壁紙設定で選ぶ。この画像は `desktop-theme apply anime-blue` では取得・設定されない。

保存先は元の Ubuntu 環境と同じ `~/Pictures/Wallpapers/gallery/images/1354384.png`。[自動切替](#ubuntu--caelestia-の自動切替)の一覧もこのパスを参照する。上記の手順では、ギャラリー全体をコピーせず同じ画像を取得できる。配布ページでは個人利用向けと案内されている。利用条件は配布元・原作者の表記に従う。

## 早瀬ユウカ / ユウカと二人きりの夜

2026-10-21 に Ubuntu / Caelestia で設定した壁紙。画像はリポジトリに含めず、取得・加工手順だけを記録する。

| 項目 | 内容 |
| --- | --- |
| 作品 | ブルーアーカイブ（早瀬ユウカ） |
| 作者 | Yisora（pixiv の作者表記。作品タグに「AIイラスト」） |
| 配布ページ | [pixiv: 130258907](https://www.pixiv.net/artworks/130258907) |
| 元画像 | `https://i.pximg.net/img-original/img/2025/05/10/21/17/20/130258907_p0.png` |
| 解像度・形式 | 7000×3966、PNG |
| SHA-256（元画像） | `bbf45b79da59a6b3b43b4a8079d2bc8d0aeb18d40b364f23ccaef472833c1e44` |

作品ページに表示される `img-master/..._master1200.jpg` は 1200×680 の縮小 JPEG なので使わない。元画像は pixiv の Referer がないと 403 になる。

```bash
dir="$HOME/Pictures/Wallpapers/gallery/images"
mkdir -p "$dir"
curl --fail --location --retry 3 -H 'Referer: https://www.pixiv.net/' \
  'https://i.pximg.net/img-original/img/2025/05/10/21/17/20/130258907_p0.png' \
  --output "$dir/pixiv-130258907.png"
shasum -a 256 "$dir/pixiv-130258907.png"
# 3440×1440（UWQHD）用。中央より上寄せで、頭上の飾りまで入れる。
magick "$dir/pixiv-130258907.png" -resize 3440x -crop 3440x1440+0+50 +repage -alpha off \
  "$dir/pixiv-130258907-uwqhd.png"
```

クロップの縦位置は `+0+50`（横幅 3440 に縮小した画像の上端から 50px）。中央は `+0+254`。値を小さくすると絵が下がる。利用条件は配布元・原作者の表記に従う。

## Ubuntu / Caelestia の自動切替

Caelestia のときは、`platforms/ubuntu/caelestia/wallpapers.json` に並べた画像を `rotation_seconds`（既定 3600 秒）ごとに順番に切り替える。パスはホームディレクトリからの相対パス。存在しない画像は飛ばし、1 枚もなければ従来どおり `caelestia wallpaper -r` でランダムに選ぶ。

- Hyprland のログイン時に `scripts/hyprland-session.sh` が `ubuntu-theme.py rotate` を起動する。ログイン直後は Caelestia が復元した壁紙を 1 周期維持する。
- `Super+Ctrl+Alt+W` でも一覧の次の画像へ進む。
- 一覧を編集した場合、次の切替から反映される（再ログイン不要）。

## 方針

macOS では [Desktop themes](desktop-themes.md) で、Ghostty・SketchyBar と一緒に壁紙セットを切り替える。`walnut` は実写風景、`anime-blue` はアニメ風の海辺を使う。以下は従来の写真用インストーラの説明。

外部ディスプレイは 3440×1440 だが、以前の `-qhd.png` は 2560×1440 だったため、表示時に横方向へ約 1.34 倍拡大されていた。また、生成画像に含まれる不自然な細部は、単純なアップスケールでは改善しない。

`scripts/install-photo-wallpapers.sh` は、元画像の解像度を確認してから次の二種類を中央クロップで作成する。必要なピクセル数を満たさない画像は拡大せず、処理を中止する。

- `*-qhd.png`: 3440×1440（UWQHD 外部ディスプレイ用）
- `*-macbook.png`: 3456×2234（MacBook 用。小さい画面では縮小表示）

## インストール

```bash
scripts/install-photo-wallpapers.sh
```

保存先は既定で `~/Pictures/Wallpapers/codex`。変更する場合は `WALLPAPER_DIR` を指定する。

## 写真の出典

- [Panoramic mountain lake](https://www.pexels.com/photo/lake-beside-mountain-14786072/) — Elias Tigiser, Pexels
- [Rio Grande sunset](https://unsplash.com/photos/landscape-photography-of-river-leading-to-mountain-0JJzYdoq62c) — Kyle Glenn, Unsplash

各写真は、それぞれの配布ページに記載されたライセンスに従って使用する。
