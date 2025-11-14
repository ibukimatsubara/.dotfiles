-- =====================================================
-- LSP + nvim-cmp（補完）
-- =====================================================

return {
  -- LSP設定
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- Python用LSP（jedi優先、なければpyright）
      if vim.fn.executable("jedi-language-server") == 1 then
        vim.lsp.config.jedi_language_server = {
          cmd = { "jedi-language-server" },
          filetypes = { "python" },
          settings = {
            completion = {
              disableSnippets = true, -- スニペット無効（軽量化）
            },
          },
          root_markers = { ".git", "pyproject.toml", "setup.py" },
        }
        vim.lsp.enable("jedi_language_server")
      elseif vim.fn.executable("pyright") == 1 then
        vim.lsp.config.pyright = {
          cmd = { "pyright-langserver", "--stdio" },
          filetypes = { "python" },
          root_markers = { ".git", "pyproject.toml", "setup.py" },
        }
        vim.lsp.enable("pyright")
      end

      -- LSPキーマップ
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
      vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Find references" })
      vim.keymap.set("n", "<S-K>", vim.lsp.buf.hover, { desc = "Show hover (Shift+K)" })
    end,
  },

  -- nvim-cmp（補完エンジン）
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
    },
    config = function()
      local cmp = require("cmp")

      cmp.setup({
        -- スニペット無効（軽量化）
        snippet = {
          expand = function(args)
            -- スニペット無効
          end,
        },

        -- キーマップ（Copilotと分離、tmux/yabaiと競合回避）
        mapping = cmp.mapping.preset.insert({
          ["<C-]>"] = cmp.mapping.complete(), -- 補完メニュー表示
          ["<C-n>"] = cmp.mapping.select_next_item(), -- 次の候補
          ["<C-p>"] = cmp.mapping.select_prev_item(), -- 前の候補
          ["<C-y>"] = cmp.mapping.confirm({ select = true }), -- 選択確定
          ["<C-e>"] = cmp.mapping.abort(), -- キャンセル
        }),

        -- 補完ソース（優先順位順）
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 }, -- LSP補完
          { name = "buffer", priority = 500, keyword_length = 3 }, -- バッファ内の単語
        }),

        -- パフォーマンス設定
        performance = {
          max_view_entries = 15, -- 最大表示数を制限
        },
      })
    end,
  },
}
