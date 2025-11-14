-- =====================================================
-- Autocommands
-- =====================================================

local autocmd = vim.api.nvim_create_autocmd

-- Claude Code連携: 完全自動リロード
autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  callback = function()
    local mode = vim.fn.mode()
    if not mode:match("[crt!]") and vim.fn.getcmdwintype() == "" then
      vim.cmd("checktime")
    end
  end,
})

-- ファイルが外部で変更された時の自動リロード
autocmd("FileChangedShell", {
  pattern = "*",
  callback = function()
    vim.cmd("silent! e!")
    print("File auto-reloaded from disk")
  end,
})

-- 編集中でも外部変更を検知したら自動リロード
autocmd({ "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  callback = function()
    vim.cmd("silent! checktime")
    -- v:fcs_reasonのチェックはVimScriptのみで有効なため、ここでは省略
  end,
})

-- コマンドライン/ターミナル終了時のチェック
autocmd({ "CmdlineLeave", "TermLeave" }, {
  pattern = "*",
  command = "checktime",
})

-- 保存前に外部変更をチェック
autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    if not vim.bo.modified then
      return
    end
    local save_cursor = vim.fn.getpos(".")
    vim.cmd("silent! checktime")
    vim.fn.setpos(".", save_cursor)
  end,
})

-- ペーストモードの設定（インデントの乱れを防ぐ）
if vim.env.TERM and vim.env.TERM:match("xterm") then
  vim.api.nvim_set_option_value("t_SI", vim.api.nvim_get_option_value("t_SI", {}) .. "\27[?2004h", {})
  vim.api.nvim_set_option_value("t_EI", vim.api.nvim_get_option_value("t_EI", {}) .. "\27[?2004l", {})
  vim.keymap.set("i", "<Esc>[200~", function()
    vim.opt.paste = true
    return ""
  end, { expr = true, noremap = true })
end
