-- =====================================================
-- Keymaps (Optionキーベース)
-- =====================================================

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ファイル操作
keymap("n", "<M-e>", "<Cmd>NvimTreeToggle<CR>", opts)
keymap("n", "<M-h>", "<Cmd>BufferLineCyclePrev<CR>", opts)
keymap("n", "<M-l>", "<Cmd>BufferLineCycleNext<CR>", opts)
keymap("n", "<M-w>", "<Cmd>bdelete<CR>", opts)

-- Claude Code連携
keymap("n", "<M-c>", "<Cmd>split | terminal claude<CR>", opts)
keymap("n", "<M-v>", "<Cmd>vsplit | terminal claude<CR>", opts)

-- ファイルパスコピー
keymap("n", "<M-p>", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  print("Copied: " .. path)
end, opts)

keymap("n", "<M-P>", function()
  local path = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", path)
  print("Copied: " .. path)
end, opts)

keymap("v", "<M-y>", '"+y', opts)

-- ファイルリロード
keymap("n", "<M-r>", "<Cmd>checktime<CR>", opts)
keymap("n", "<M-R>", "<Cmd>e!<CR>", opts)

-- ターミナルモードでのエスケープ
keymap("t", "<Esc>", "<C-\\><C-n>", opts)
keymap("t", "<M-[>", "<C-\\><C-n>", opts)

-- Git関連
keymap("n", "<M-g>s", "<Cmd>!git status<CR>", opts)
keymap("n", "<M-g>d", "<Cmd>!git diff %<CR>", opts)
keymap("n", "<M-g>b", "<Cmd>!git blame %<CR>", opts)

-- 差分表示
keymap("n", "<M-d>", "<Cmd>DiffOrig<CR>", opts)
vim.cmd([[
  command! DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis
]])

-- その他
keymap("n", "<M-o>", function()
  vim.opt.readonly = not vim.opt.readonly:get()
  print("Read-only: " .. (vim.opt.readonly:get() and "ON" or "OFF"))
end, opts)

keymap("n", "<M-m>", "<Cmd>e README.md<CR>", opts)
