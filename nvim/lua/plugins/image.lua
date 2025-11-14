-- =====================================================
-- Image Preview: image.nvim
-- Kitty Graphics Protocolで画像をインライン表示
-- =====================================================

return {
  "3rd/image.nvim",
  dependencies = {
    -- luarocksとmagickの自動セットアップ
    {
      "vhyrro/luarocks.nvim",
      priority = 1000,
      config = true,
      opts = {
        rocks = { "magick" },
      },
    },
  },
  event = "VeryLazy",
  opts = {
    backend = "kitty", -- Kittyターミナルを使用
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false, -- インサートモードでも画像を表示し続ける
        download_remote_images = true, -- ネット上の画像もダウンロードして表示
        only_render_image_at_cursor = false, -- すべての画像を表示
        filetypes = { "markdown", "vimwiki" },
      },
      neorg = {
        enabled = false, -- Neorgは使用しない
      },
      html = {
        enabled = false,
      },
      css = {
        enabled = false,
      },
    },
    max_width = 100, -- 画像の最大幅（文字数換算）
    max_height = 12, -- 画像の最大高さ
    max_width_window_percentage = nil,
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = false,
    window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    editor_only_render_when_focused = false,
    tmux_show_only_in_active_window = false,
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp" },
  },
}
