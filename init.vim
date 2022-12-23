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
filetype plugin indent off

" dein.vim settings {{{
" install dir {{{
let s:dein_dir = expand('~/.config/nvim/dein')
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'
" }}}

" dein installation check {{{
if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif
  execute 'set runtimepath^=' . s:dein_repo_dir
endif
" }}}

" begin settings {{{
if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  " .toml file
  let s:rc_dir = expand('~/.config/nvim/toml')
  if !isdirectory(s:rc_dir)
    call mkdir(s:rc_dir, 'p')
  endif
  let s:toml = s:rc_dir . '/dein.toml'
  let s:tomllazy = s:rc_dir . '/dein_lazy.toml'

  " read toml and cache
  call dein#load_toml(s:toml, {'lazy': 0})

  call dein#load_toml(s:tomllazy, {'lazy': 1})

  " end settings
  call dein#end()
  call dein#save_state()
endif
" }}}

" plugin installation check {{{
if dein#check_install()
  call dein#install()
endif
" }}}

" plugin remove check {{{
let s:removed_plugins = dein#check_clean()
if len(s:removed_plugins) > 0
  call map(s:removed_plugins, "delete(v:val, 'rf')")
  call dein#recache_runtimepath()
endif
" }}}

set t_Co=256
" color scheme
" colorscheme atom-dark-256
" colorscheme atom-dark
colorscheme hatsunemiku
set t_Co=256

let g:lightline = { 'colorscheme': 'hatsunemiku' }

autocmd ColorScheme * highlight Normal ctermbg=none
autocmd ColorScheme * highlight LineNr ctermbg=none
autocmd ColorScheme * highlight CursorLine ctermbg=none cterm=none
autocmd ColorScheme * highlight CursorLineNr ctermbg=none cterm=underline

syntax enable
"set textwidth=79
"set colorcolumn=+1
"highlight ColorColumn guibg=#202020 ctermbg=lightgray
