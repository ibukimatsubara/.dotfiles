-- =====================================================
-- Git: vim-signify
-- =====================================================

return {
  "mhinz/vim-signify",
  event = "BufReadPre", -- ファイル読み込み前に遅延ロード
  config = function()
    vim.g.signify_sign_add = "+"
    vim.g.signify_sign_delete = "-"
    vim.g.signify_sign_change = "~"
    vim.g.signify_sign_show_count = 0
  end,
}
