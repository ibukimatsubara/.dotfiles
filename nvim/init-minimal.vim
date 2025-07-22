" Minimal Neovim configuration - 軽量版
" 基本的なエディタ設定
set encoding=utf-8
scriptencoding utf-8
set number relativenumber
set wildmenu
set autoindent
set clipboard=unnamed
set hls
set colorcolumn=80
set backspace=indent,eol,start
set cursorline

set t_Co=256
let mapleader = ','

" 折りたたみの設定
set foldmethod=indent
set foldlevel=99

" ペーストモードの設定
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

" UI設定（ステータスライン非表示）
set cmdheight=0
set noshowmode
set laststatus=0

" タブとインデントの設定
set expandtab
set tabstop=2
set softtabstop=2
set shiftwidth=2

" プラグイン管理（vim-plug）- 最小限のみ
call plug#begin('~/.local/share/nvim/site/autoload/')

" ファイラー（軽量）
Plug 'lambdalisue/vim-fern'
nnoremap <leader>n :Fern . -drawer<CR>

" 囲み文字操作
Plug 'kylechui/nvim-surround'

" Git差分表示（シンプル版）
Plug 'mhinz/vim-signify'
let g:signify_sign_add = '+'
let g:signify_sign_delete = '-'
let g:signify_sign_change = '~'

" ファジーファインダー（FZF - 軽量）
Plug 'junegunn/fz'
Plug 'junegunn/fzf.vim'
nnoremap <leader>f :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>g :Rg<CR>

" カラースキーム
Plug '4513ECHO/vim-colors-hatsunemiku'

" 遅延読み込みでLaTeX（必要な時のみ）
Plug 'lervag/vimtex', { 'for': ['tex', 'latex'] }

call plug#end()

" カラースキームの設定
colorscheme hatsunemiku
autocmd ColorScheme * highlight Normal ctermbg=none
autocmd ColorScheme * highlight LineNr ctermbg=none
autocmd ColorScheme * highlight CursorLine ctermbg=none cterm=none
autocmd ColorScheme * highlight CursorLineNr ctermbg=none cterm=underline

" シンタックスハイライトを有効化
syntax enable
set textwidth=79
set colorcolumn=+1
highlight ColorColumn guibg=#202020 ctermbg=0

" Claude Code連携設定（そのまま）
set autoread
set updatetime=100
autocmd FocusGained,BufEnter * checktime
autocmd FileChangedShell * echo "Warning: File changed on disk"

function! CheckFileChanged()
    if !&modified
        return
    endif
    let l:save_cursor = getpos('.')
    silent! checktime
    call setpos('.', l:save_cursor)
endfunction
autocmd BufWritePre * call CheckFileChanged()

" キーマッピング（基本的なもののみ）
nnoremap <leader>cc :split \| terminal claude<CR>
nnoremap <leader>ct :vsplit \| terminal claude<CR>
tnoremap <Esc> <C-\><C-n>
nnoremap <leader>cp :let @+ = expand('%:p')<CR>:echo "Copied: " . expand('%:p')<CR>
nnoremap <leader>cl :let @+ = expand('%:p') . ':' . line('.')<CR>:echo "Copied: " . expand('%:p') . ':' . line('.')<CR>
vnoremap <leader>cy "+y