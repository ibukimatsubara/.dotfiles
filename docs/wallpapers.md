# Desktop wallpapers

## 方針

現在は [Desktop themes](desktop-themes.md) で、Ghostty・SketchyBar と一緒に壁紙セットを切り替える。`walnut` は実写風景、`anime-blue` はアニメ風の海辺を使う。以下は従来の写真用インストーラの説明。

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
