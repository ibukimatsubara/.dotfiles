-- =====================================================
-- Bufferline: タブライン表示
-- =====================================================

return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = "nvim-tree/nvim-web-devicons",
  event = "VeryLazy", -- 起動後に遅延ロード
  config = function()
    require("bufferline").setup({
      options = {
        offsets = {
          {
            filetype = "NvimTree",
            text = "Files",
            highlight = "Directory",
            text_align = "left",
          },
        },
        show_close_icon = false,
        show_buffer_close_icons = false,
      },
    })
  end,
}
