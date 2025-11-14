-- =====================================================
-- Neovim Configuration (Lazy.nvim)
-- =====================================================

-- Lazy.nvimのブートストラップ（初回起動時に自動インストール）
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.runtimepath:prepend(lazypath)

-- リーダーキーの設定（プラグイン読み込み前に設定必須）
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- 基本設定の読み込み
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- プラグインの読み込み
require("lazy").setup("plugins", {
  -- パフォーマンス設定
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  -- UI設定
  ui = {
    border = "rounded",
  },
  -- 自動チェックを無効化（起動高速化）
  checker = {
    enabled = false,
  },
  -- 変更検知を無効化（起動高速化）
  change_detection = {
    enabled = false,
  },
})
