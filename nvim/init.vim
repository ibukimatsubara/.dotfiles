" 最小限のNeovim設定
" 基本的なエディタ設定
set encoding=utf-8
scriptencoding utf-8
set number relativenumber  " 行番号と相対行番号を表示
set wildmenu  " コマンドライン補完を拡張
set autoindent  " 自動インデント
set clipboard=unnamed  " システムのクリップボードを使用
set hls  " 検索結果をハイライト
set colorcolumn=80  " 80文字目にラインを表示
set backspace=indent,eol,start  " バックスペースの動作を調整
set cursorline  " カーソル行をハイライト

set t_Co=256  " 256色対応
let mapleader = ','  " リーダーキーを,に設定

" パフォーマンス最適化
set ttyfast              " 高速ターミナル
set lazyredraw           " マクロ実行中の再描画を無効
set synmaxcol=200        " 長い行のシンタックス制限
set undolevels=1000      " undo履歴制限
set history=500          " コマンド履歴制限

" 折りたたみの設定
set foldmethod=indent
set foldlevel=99

" ペーストモードの設定（インデントの乱れを防ぐ）
if &term =~ "xterm"
    let &t_SI .= "\e[?2004h"
    let &t_EI .= "\e[?2004l"
    let &pastetoggle = "\e[201~"
    function XTermPasteBegin(ret)
        set paste
        return a:ret
    endfunction
    inoremap <special> <expr> <Esc>[200~ XTermPasteBegin("")
endif

" コマンドラインをオフ
set cmdheight=0
set noshowmode
set laststatus=0

" タブとインデントの設定
set expandtab
set tabstop=2
set softtabstop=2
set shiftwidth=2

" プラグイン管理（vim-plug）
call plug#begin('~/.local/share/nvim/site/autoload/')

" カラースキーム（必須）
Plug '4513ECHO/vim-colors-hatsunemiku'

" Git差分表示（シンプル版）
Plug 'mhinz/vim-signify'

" GitHub Copilot（AI補完）
Plug 'github/copilot.vim'

" 軽量LSPと補完（プロジェクト全体の関数認識用）
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'  " バッファから補完（超軽量）

" ファイルエクスプローラー
Plug 'nvim-tree/nvim-tree.lua'
Plug 'nvim-tree/nvim-web-devicons'

" タブライン表示
Plug 'akinsho/bufferline.nvim', { 'tag': '*' }

call plug#end()

" カラースキームの設定
try
  colorscheme hatsunemiku
catch
  echo "hatsunemiku theme not found. Run :PlugInstall"
endtry

" 背景色の設定（完全透明化）
highlight Normal ctermbg=none guibg=none
highlight LineNr ctermbg=none guibg=none
highlight CursorLine ctermbg=none guibg=none cterm=none gui=none
highlight CursorLineNr ctermbg=none guibg=none cterm=underline gui=underline
highlight NonText ctermbg=none guibg=none
highlight EndOfBuffer ctermbg=none guibg=none
highlight SignColumn ctermbg=none guibg=none

" シンタックスハイライトを有効化
syntax enable
set textwidth=0
set colorcolumn=+1
highlight ColorColumn guibg=#202020 ctermbg=0

" Git差分表示の設定（シンプル）
let g:signify_sign_add = '+'
let g:signify_sign_delete = '-'
let g:signify_sign_change = '~'
let g:signify_sign_show_count = 0

" Claude Code連携設定
" ファイル競合回避のための自動リロード
set autoread
set updatetime=100

" 完全自動リロード - 常に外部の変更を優先
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * 
  \ if mode() !~ '\v(c|r.?|!|t)' && getcmdwintype() == '' | checktime | endif

" ファイルが外部で変更された時は常に自動リロード
set autoread
autocmd FileChangedShell * 
  \ execute 'silent! e!' |
  \ echo "File auto-reloaded from disk"

" 編集中でも外部変更を検知したら自動リロード
autocmd CursorHold,CursorHoldI * 
  \ silent! checktime |
  \ if v:fcs_reason == 'changed' |
  \   execute 'silent! e!' |
  \ endif

" より頻繁にチェック（100ms）
set updatetime=100

" スワップファイルを無効化（自動リロードとの競合を防ぐ）
set noswapfile
set nobackup
set nowritebackup

" 保存前に外部変更をチェック
function! CheckFileChanged()
    if !&modified
        return
    endif
    let l:save_cursor = getpos('.')
    silent! checktime
    call setpos('.', l:save_cursor)
endfunction
autocmd BufWritePre * call CheckFileChanged()

" Optionキー（Alt/Meta）ベースのキーマップ
" macOSでは Option as Meta を有効にする必要あり

" ファイル操作
nnoremap <M-e> :NvimTreeToggle<CR>
nnoremap <M-h> <Cmd>BufferLineCyclePrev<CR>
nnoremap <M-l> <Cmd>BufferLineCycleNext<CR>
nnoremap <M-w> <Cmd>bdelete<CR>

" Claude Code連携
nnoremap <M-c> :split \| terminal claude<CR>
nnoremap <M-v> :vsplit \| terminal claude<CR>
nnoremap <M-p> :let @+ = expand('%:p')<CR>:echo "Copied: " . expand('%:p')<CR>
nnoremap <M-P> :let @+ = expand('%:p') . ':' . line('.')<CR>:echo "Copied: " . expand('%:p') . ':' . line('.')<CR>
vnoremap <M-y> "+y

" ファイルリロード
nnoremap <M-r> :checktime<CR>
nnoremap <M-R> :e!<CR>

" ターミナルモードでのエスケープ
tnoremap <Esc> <C-\><C-n>
tnoremap <M-[> <C-\><C-n>

" Git関連
nnoremap <M-g>s :!git status<CR>
nnoremap <M-g>d :!git diff %<CR>
nnoremap <M-g>b :!git blame %<CR>

" 差分表示
nnoremap <M-d> :DiffOrig<CR>
command! DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis

" その他
nnoremap <M-o> :set readonly!<CR>:echo "Read-only: " . (&readonly ? "ON" : "OFF")<CR>
nnoremap <M-m> :e README.md<CR>

" 従来のリーダーキーマップも残す（互換性のため）
autocmd CmdlineLeave,TermLeave * checktime

" ========================================
" GitHub Copilot設定
" ========================================
" Copilotを有効化
let g:copilot_no_tab_map = v:true
imap <silent><script><expr> <Tab> copilot#Accept("\<Tab>")
imap <C-J> <Plug>(copilot-next)
imap <C-K> <Plug>(copilot-previous)

" Copilot表示設定（視認性向上）
highlight CopilotSuggestion ctermfg=8 ctermbg=none guifg=#5c6370 guibg=none
highlight CopilotAnnotation ctermfg=8 ctermbg=none guifg=#5c6370 guibg=none

" ========================================
" nvim-tree設定
" ========================================
lua << EOF
-- nvim-treeの設定
require("nvim-tree").setup({
  -- 基本設定
  disable_netrw = true,
  hijack_netrw = true,
  hijack_cursor = false,
  hijack_unnamed_buffer_when_opening = false,

  -- ビュー設定
  view = {
    width = 30,
    side = "left",
    number = false,
    relativenumber = false,
    signcolumn = "yes",
  },

  -- レンダラー設定
  renderer = {
    add_trailing = false,
    group_empty = false,
    highlight_git = true,
    highlight_opened_files = "none",
    root_folder_modifier = ":~",
    indent_markers = {
      enable = true,
      icons = {
        corner = "└ ",
        edge = "│ ",
        none = "  ",
      },
    },
    icons = {
      webdev_colors = true,
      git_placement = "before",
      padding = " ",
      symlink_arrow = " ➛ ",
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,
      },
      glyphs = {
        default = "",
        symlink = "",
        folder = {
          arrow_closed = "",
          arrow_open = "",
          default = "",
          open = "",
          empty = "",
          empty_open = "",
          symlink = "",
          symlink_open = "",
        },
        git = {
          unstaged = "✗",
          staged = "✓",
          unmerged = "",
          renamed = "➜",
          untracked = "★",
          deleted = "",
          ignored = "◌",
        },
      },
    },
  },

  -- ファイルフィルター
  filters = {
    dotfiles = false,
    custom = { ".git", "node_modules", ".cache" },
  },

  -- Git設定
  git = {
    enable = true,
    ignore = true,
    timeout = 400,
  },

  -- その他設定
  update_focused_file = {
    enable = true,
    update_cwd = true,
    ignore_list = {},
  },

  actions = {
    use_system_clipboard = true,
    change_dir = {
      enable = true,
      global = false,
      restrict_above_cwd = false,
    },
    open_file = {
      quit_on_open = false,
      resize_window = false,
      window_picker = {
        enable = true,
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
        exclude = {
          filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
          buftype = { "nofile", "terminal", "help" },
        },
      },
    },
  },
})
EOF

" nvim-tree最小設定
lua << EOF
require("nvim-tree").setup({
  view = { width = 30 },
  renderer = { icons = { show = { git = false, folder_arrow = false } } },
  filters = { custom = { ".git", "node_modules" } },
})
EOF

" bufferline最小設定
lua << EOF
require('bufferline').setup {
  options = {
    offsets = {{ filetype = "NvimTree", text = "Files" }},
    show_close_icon = false,
    show_buffer_close_icons = false,
  }
}
EOF


" ========================================
" LSPと補完設定（Copilotと共存、軽量版）
" ========================================
lua << EOF
-- LSP設定（Neovim 0.11+対応）
-- Python用（jedi推奨 - pyrightより軽量）
-- pip install jedi-language-server でインストール
if vim.fn.executable('jedi-language-server') == 1 then
  vim.lsp.config.jedi_language_server = {
    cmd = {'jedi-language-server'},
    filetypes = {'python'},
    settings = {
      completion = {
        disableSnippets = true,  -- スニペット無効（軽量化）
      }
    },
    root_markers = {'.git', 'pyproject.toml', 'setup.py'},
  }
  vim.lsp.enable('jedi_language_server')
elseif vim.fn.executable('pyright') == 1 then
  vim.lsp.config.pyright = {
    cmd = {'pyright-langserver', '--stdio'},
    filetypes = {'python'},
    root_markers = {'.git', 'pyproject.toml', 'setup.py'},
  }
  vim.lsp.enable('pyright')
end

-- nvim-cmp設定（Copilotと競合しないように）
local cmp = require'cmp'
cmp.setup({
  -- スニペット無効（軽量化）
  snippet = {
    expand = function(args)
      -- スニペット無効
    end,
  },

  -- キーマップ（Copilotと分離、tmux/yabaiと競合回避）
  mapping = cmp.mapping.preset.insert({
    ['<C-]>'] = cmp.mapping.complete(),  -- 補完メニュー表示
    ['<C-n>'] = cmp.mapping.select_next_item(),  -- 次の候補
    ['<C-p>'] = cmp.mapping.select_prev_item(),  -- 前の候補
    ['<C-y>'] = cmp.mapping.confirm({ select = true }),  -- 選択確定
    ['<C-e>'] = cmp.mapping.abort(),  -- キャンセル
    -- TabはCopilot用、Ctrl+J/KはCopilotとtmuxで使用済み
  }),

  -- 補完ソース（優先順位順）
  sources = cmp.config.sources({
    { name = 'nvim_lsp', priority = 1000 },  -- LSP補完
    { name = 'buffer', priority = 500, keyword_length = 3 },  -- バッファ内の単語
  }),

  -- パフォーマンス設定
  performance = {
    max_view_entries = 15,  -- 最大表示数を制限
  },
})

-- LSPキーマップ（競合回避）
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })
vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc = 'Find references' })
vim.keymap.set('n', '<S-K>', vim.lsp.buf.hover, { desc = 'Show hover (Shift+K)' })  -- Kは避けてShift+K使用
EOF

" 補完メニューの見た目（軽量化）
set pumheight=10  " 補完メニューの最大高さ
set completeopt=menu,menuone,noselect