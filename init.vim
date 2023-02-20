" edita setting
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

" ペーストの空白を揃える
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

" tab setting
setlocal expandtab
retab 2
setlocal tabstop=2
setlocal softtabstop=2
setlocal shiftwidth=2

"  *********************** Plugins **************************
"
call plug#begin('~/.local/share/nvim/site/autoload/')

" Coc
Plug 'neoclide/coc.nvim', {'branch': 'release'}
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~ '\s'
endfunction
inoremap <silent><expr> <TAB>
  \ pumvisible() ? "\<C-n>" :
  \ <SID>check_back_space() ? "\<TAB>" :
  \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <CR> pumvisible() ? coc#pum#confirm() : "\<CR>"
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

Plug 'alvan/vim-closetag'

" View

Plug 'ryanoasis/vim-devicons'

Plug 'luochen1990/rainbow'
let g:rainbow_active = 1

Plug 'Maan2003/lsp_lines.nvim'
lua << EOF
vim.diagnostic.config({ virtual_lines = true })
EOF

Plug 'j-hui/fidget.nvim'

Plug 'lukas-reineke/indent-blankline.nvim'
lua << EOF
vim.opt.list = true
vim.opt.listchars:append "eol:↴"
EOF


Plug 'airblade/vim-gitgutter'

Plug '4513ECHO/vim-colors-hatsunemiku'

Plug 'itchyny/lightline.vim'
set laststatus=2
set showmode
set showcmd
set ruler

call plug#end()

colorscheme hatsunemiku
autocmd ColorScheme * highlight Normal ctermbg=none
autocmd ColorScheme * highlight LineNr ctermbg=none
autocmd ColorScheme * highlight CursorLine ctermbg=none cterm=none
autocmd ColorScheme * highlight CursorLineNr ctermbg=none cterm=underline

let g:lightline = { 'colorscheme': 'hatsunemiku' }

filetype indent off
filetype plugin off


syntax enable
set textwidth=79
set colorcolumn=+1
highlight ColorColumn guibg=#202020 ctermbg=lightgray
