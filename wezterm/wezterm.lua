local wezterm = require 'wezterm'

return {
  -- タブバーを非表示にする
  enable_tab_bar = false,
  
  -- フォント設定
  font = wezterm.font('Hack Nerd Font', { weight = 'Regular' }),
  font_size = 11.0,
  
  -- テーマ設定
  color_scheme = 'Builtin Dark',
  
  -- カスタムカラー（背景とハイライトのみ）
  colors = {
    background = '#1e2124',  -- 非常に濃いダークグレー
    selection_bg = '#404040',  -- 選択時の背景を暗い灰色に
    selection_fg = '#ffffff',  -- 選択時の文字を白に
    compose_cursor = '#1e2124',  -- 日本語入力時のカーソル背景を無効化
  },
  
  -- カーソル設定
  cursor_blink_rate = 500,
  default_cursor_style = 'BlinkingBlock',
  
  -- スクロールバック
  scrollback_lines = 10000,
}