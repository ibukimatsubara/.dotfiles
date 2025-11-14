-- =====================================================
-- Neovim Options
-- =====================================================

local opt = vim.opt

-- エンコーディング
vim.scriptencoding = "utf-8"
opt.encoding = "utf-8"

-- 行番号
opt.number = true
opt.relativenumber = true

-- UI設定
opt.wildmenu = true
opt.cursorline = true
opt.colorcolumn = "80"
opt.signcolumn = "yes"
opt.termguicolors = true

-- インデント
opt.autoindent = true
opt.expandtab = true
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2

-- 検索
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- 折りたたみ
opt.foldmethod = "indent"
opt.foldlevel = 99

-- クリップボード
opt.clipboard = "unnamed"

-- バックスペース
opt.backspace = { "indent", "eol", "start" }

-- パフォーマンス最適化
opt.ttyfast = true
opt.lazyredraw = true
opt.synmaxcol = 200
opt.undolevels = 1000
opt.history = 500
opt.updatetime = 100

-- コマンドライン
opt.cmdheight = 0
opt.showmode = false
opt.laststatus = 0

-- スワップファイル無効化（自動リロードとの競合を防ぐ）
opt.swapfile = false
opt.backup = false
opt.writebackup = false

-- 自動リロード設定
opt.autoread = true

-- 補完メニュー
opt.pumheight = 10
opt.completeopt = { "menu", "menuone", "noselect" }

-- テキスト幅
opt.textwidth = 0
