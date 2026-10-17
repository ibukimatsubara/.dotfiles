# Ghostty Configuration

## Ubuntu / Linux

`./setup.sh` links `config-linux` and the shaders into the Ghostty config
directory (`$XDG_CONFIG_HOME/ghostty`, or `~/.config/ghostty`). Ghostty must
already be installed. The macOS config remains separate for Hammerspoon.

- Copy/paste: `Ctrl+Shift+C` / `Ctrl+Shift+V`
- New window: `Ctrl+Shift+N`
- tmux new/close/rename window: `Ctrl+Shift+T` / `Ctrl+Shift+W` / `Ctrl+Shift+R`
- Reload config: `Ctrl+Shift+,`

Validate with `ghostty +validate-config`. Background transparency depends on
the desktop compositor; the Linux config does not request macOS blur.

## Break Timer Wallpaper

休憩タイマーが ON の間だけ、Ghostty に背景画像を表示できます。OFF にすると Hammerspoon が `background-image-opacity = 0` に戻して非表示にします。

現在の標準設定では `wallpaper_enabled = false` とし、Ghostty の透過・ブラーだけを使用します。背景画像を使う場合のみ `true` に変更してください。

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
