-- =====================================================
-- GitHub Copilot
-- =====================================================

return {
  "github/copilot.vim",
  event = "InsertEnter", -- インサートモード時に遅延ロード
  config = function()
    vim.g.copilot_no_tab_map = true

    -- Copilotキーマップ
    vim.keymap.set("i", "<Tab>", 'copilot#Accept("\\<Tab>")', {
      expr = true,
      silent = true,
      script = true,
      replace_keycodes = false,
    })
    vim.keymap.set("i", "<C-J>", "<Plug>(copilot-next)", {})
    vim.keymap.set("i", "<C-K>", "<Plug>(copilot-previous)", {})

    -- Copilot表示設定（視認性向上）
    vim.api.nvim_set_hl(0, "CopilotSuggestion", { ctermfg = 8, ctermbg = "none", fg = "#5c6370", bg = "none" })
    vim.api.nvim_set_hl(0, "CopilotAnnotation", { ctermfg = 8, ctermbg = "none", fg = "#5c6370", bg = "none" })
  end,
}
