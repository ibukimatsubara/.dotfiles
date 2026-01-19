#!/bin/bash
# Ghostty起動時にランダムな壁紙を選択するスクリプト

WALLPAPER_DIR="$HOME/.dotfiles/ghostty/wallpapers"
CONFIG_FILE="$HOME/.dotfiles/ghostty/config"

# 壁紙ディレクトリから画像をランダムに選択
shopt -s nullglob
images=("$WALLPAPER_DIR"/*.jpg "$WALLPAPER_DIR"/*.jpeg "$WALLPAPER_DIR"/*.png "$WALLPAPER_DIR"/*.gif)
shopt -u nullglob

if [ ${#images[@]} -eq 0 ]; then
    echo "No images found in $WALLPAPER_DIR"
    exit 1
fi

# ランダムに1つ選択
random_image="${images[$RANDOM % ${#images[@]}]}"

# 設定ファイルの背景画像パスを更新
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^background-image = .*|background-image = $random_image|" "$CONFIG_FILE"
else
    sed -i "s|^background-image = .*|background-image = $random_image|" "$CONFIG_FILE"
fi

echo "Selected wallpaper: $random_image"
