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
setlocal expandtab
retab 2
setlocal tabstop=2
setlocal softtabstop=2
setlocal shiftwidth=2

" プラグイン管理（vim-plug）
call plug#begin('~/.local/share/nvim/site/autoload/')

" CoC (Conquer of Completion) の設定
Plug 'neoclide/coc.nvim', {'branch': 'release'}
" CoC の補完機能のキーマッピング
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <CR> pumvisible() ? coc#pum#confirm() : "\<CR>"
" CoC のコードナビゲーション機能のキーマッピング
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" 自動タグ閉じプラグイン
Plug 'alvan/vim-closetag'

" Telescope（ファジーファインダー）の依存プラグイン
Plug 'MunifTanjim/nui.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

" アイコン表示プラグイン
Plug 'ryanoasis/vim-devicons'

" 括弧やタグに色を付けるプラグイン
Plug 'luochen1990/rainbow'
let g:rainbow_active = 1

" LSPの進捗表示プラグイン
Plug 'j-hui/fidget.nvim'

" インデントガイドラインプラグイン
Plug 'lukas-reineke/indent-blankline.nvim'
lua << EOF
vim.opt.list = true
EOF
"vim.opt.listchars:append "eol:"

" Gitの差分表示プラグイン
Plug 'airblade/vim-gitgutter'

" カラースキーム
Plug '4513ECHO/vim-colors-hatsunemiku'

" LaTeX編集支援プラグイン
Plug 'lervag/vimtex'
let g:vimtex_view_general_viewer = 'displayline'
let g:vimtex_view_general_options = '-r @line @pdf @tex'
let g:tex_flavor = "latex"
let maplocalleader=' '


Plug 'kylechui/nvim-surround'

Plug 'lambdalisue/vim-fern'

" modeをカーソルに表示するプラグイン
Plug 'mvllow/modes.nvim'


call plug#end()


" カラースキームの設定
colorscheme hatsunemiku
" 背景色の設定
autocmd ColorScheme * highlight Normal ctermbg=none
autocmd ColorScheme * highlight LineNr ctermbg=none
autocmd ColorScheme * highlight CursorLine ctermbg=none cterm=none
autocmd ColorScheme * highlight CursorLineNr ctermbg=none cterm=underline

" Lightlineのカラースキーム設定
let g:lightline = { 'colorscheme': 'hatsunemiku' }

" ファイルタイプ別のインデントとプラグインの設定を無効化
filetype indent off
filetype plugin off

" シンタックスハイライトを有効化
syntax enable
set textwidth=79
set colorcolumn=+1
highlight ColorColumn guibg=#202020 ctermbg=0

let g:coc_config_home = '~/.dotfiles'

lua << EOF
require('modes').setup({
  colors = {
    copy = "#f5c359",
    delete = "#c75c6a",
    insert = "#78ccc5",
    visual = "#9745be",
  },
  line_opacity = 0.15,
  set_cursor = true,
  set_cursorline = true,
  set_number = true,
  ignore_filetypes = { 'NvimTree', 'TelescopePrompt' }
})
EOF

