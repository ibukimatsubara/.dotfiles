" LSP版設定 - CoCの代わりに内蔵LSPを使用
" init-minimal.vimの内容を継承
source ~/.dotfiles/nvim/init-minimal.vim

" LSP設定のためのプラグイン
call plug#begin('~/.local/share/nvim/site/autoload/')

" 内蔵LSPの設定を簡単にする
Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'

" 補完（軽量）
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'L3MON4D3/LuaSnip'

call plug#end()

" LSP設定
lua << EOF
-- Mason setup
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "tsserver", "pyright", "lua_ls" },
  automatic_installation = true,
})

-- LSP設定
local lspconfig = require('lspconfig')
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- 各言語サーバーの設定
lspconfig.tsserver.setup{ capabilities = capabilities }
lspconfig.pyright.setup{ capabilities = capabilities }
lspconfig.lua_ls.setup{ capabilities = capabilities }

-- 補完設定
local cmp = require'cmp'
cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<Tab>'] = cmp.mapping.select_next_item(),
    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'buffer' },
    { name = 'path' },
  })
})

-- キーマッピング
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
vim.keymap.set('n', 'gr', vim.lsp.buf.references)
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation)
vim.keymap.set('n', 'K', vim.lsp.buf.hover)
EOF