-- =====================================================
-- Colorscheme: Hatsune Miku
-- =====================================================

return {
  "4513ECHO/vim-colors-hatsunemiku",
  lazy = false, -- 起動時に即読み込み（カラースキームは必須）
  priority = 1000, -- 最優先で読み込み
  config = function()
    vim.cmd([[colorscheme hatsunemiku]])

    -- 背景色の設定（完全透明化）
    -- Neovim 0.11+ uses "bg" instead of legacy gui/cterm keys
    local highlights = {
      Normal = { bg = "none" },
      LineNr = { bg = "none" },
      CursorLine = { bg = "none" },
      CursorLineNr = { bg = "none", underline = true },
      NonText = { bg = "none" },
      EndOfBuffer = { bg = "none" },
      SignColumn = { bg = "none" },
      ColorColumn = { bg = "#202020" },
    }

    for group, settings in pairs(highlights) do
      vim.api.nvim_set_hl(0, group, settings)
    end
  end,
}
