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
    local highlights = {
      Normal = { ctermbg = "none", guibg = "none" },
      LineNr = { ctermbg = "none", guibg = "none" },
      CursorLine = { ctermbg = "none", guibg = "none", cterm = "none", gui = "none" },
      CursorLineNr = { ctermbg = "none", guibg = "none", cterm = "underline", gui = "underline" },
      NonText = { ctermbg = "none", guibg = "none" },
      EndOfBuffer = { ctermbg = "none", guibg = "none" },
      SignColumn = { ctermbg = "none", guibg = "none" },
      ColorColumn = { guibg = "#202020", ctermbg = 0 },
    }

    for group, settings in pairs(highlights) do
      vim.api.nvim_set_hl(0, group, settings)
    end
  end,
}
