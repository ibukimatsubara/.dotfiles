# Ghostty Configuration

## Random Wallpaper

Ghostty起動時にランダムな背景画像を表示する機能。

### Setup

1. `ghostty/wallpapers/` ディレクトリに画像ファイルを配置:
   ```bash
   cp ~/path/to/your/image.jpg ~/.dotfiles/ghostty/wallpapers/
   ```

2. 対応フォーマット: `.jpg`, `.jpeg`, `.png`, `.gif`

3. Ghosttyを新しく開くと自動的にランダムな画像が選ばれる

### Notes

- 壁紙ファイルは `.gitignore` で除外されている (著作権のある画像を含む可能性があるため)
- 画像の透明度は `config` の `background-image-opacity` で調整可能 (デフォルト: 0.2)
