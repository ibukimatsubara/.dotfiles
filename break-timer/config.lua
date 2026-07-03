-- 休憩タイマー設定
-- 実体: ~/.dotfiles/break-timer/config.lua (~/.config/break-timer/config.lua からsymlink)
-- 保存すると Hammerspoon が自動で再読み込みし、作業サイクルを仕切り直す

return {
  -- 時間 (分)。小数も OK (0.2 = 12秒)
  work_minutes   = 30, -- 作業時間
  fade_minutes   = 3,  -- フェードにかける時間
  break_minutes  = 3,  -- 休憩時間
  snooze_minutes = 3,  -- スヌーズ(⌘P)で延長する時間

  -- 休憩画面のシーン。
  -- ~/.dotfiles/ghostty/shaders/scenes/<名前>.tpl.glsl が使われる。
  -- いまあるのは "starry" (星空)。夜景などを作ったらここを切り替える
  scene = "starry",

  -- 作業中に画面下端へ残り時間ライン(ON の目印)を出すか
  show_work_gauge = true,

  -- タイマーが ON の間だけ Ghostty の背景画像を表示する。
  -- OFF にすると background-image-opacity を 0 にして非表示にする。
  wallpaper_enabled = true,
  wallpaper_dir = os.getenv("HOME") .. "/.dotfiles/ghostty/wallpapers",
  wallpaper_opacity = 0.3,
  wallpaper_fit = "contain", -- contain / cover / stretch など Ghostty の指定に合わせる
  wallpaper_pick = "random", -- random: ON にするたび選ぶ / keep: 同じ画像を維持 / first: 名前順の先頭

  -- 状態が変わったときに画面中央へポップアップ通知を出すか。
  -- false なら状態表示は Ghostty 内(下端ゲージ/フェード/星空/明滅)だけになり、
  -- 画面共有や定例中に余計なものが写らない
  alerts = false,
}
