# Ghostty Configuration

## Break Timer Wallpaper

休憩タイマーが ON の間だけ、Ghostty に背景画像を表示できます。OFF にすると Hammerspoon が `background-image-opacity = 0` に戻して非表示にします。

### Setup

1. `ghostty/wallpapers/` ディレクトリに画像ファイルを配置:
   ```bash
   cp ~/path/to/your/image.jpg ~/.dotfiles/ghostty/wallpapers/
   ```

2. 対応フォーマット: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`

3. `break-timer/config.lua` で表示方法を調整:
   ```lua
   wallpaper_enabled = true,
   wallpaper_dir = os.getenv("HOME") .. "/.dotfiles/ghostty/wallpapers",
   wallpaper_opacity = 0.3,
   wallpaper_fit = "contain",
   wallpaper_pick = "random",
   ```

### Notes

- 壁紙ファイルは `.gitignore` で除外されている (著作権のある画像を含む可能性があるため)
- 画像の透明度は `break-timer/config.lua` の `wallpaper_opacity` で調整する (デフォルト: 0.3)
- `wallpaper_pick` は `random` / `keep` / `first` を指定できる
