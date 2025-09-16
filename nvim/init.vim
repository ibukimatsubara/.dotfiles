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
set textwidth=79
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

" 手動リロードのキーマップ
nnoremap <leader>r :checktime<CR>
nnoremap <leader>R :e!<CR>

" ターミナルやコマンドラインから戻った時も確認
autocmd CmdlineLeave,TermLeave * checktime

" Claude Code用キーマップ
" ターミナルを素早く開く
nnoremap <leader>cc :split \| terminal claude<CR>
nnoremap <leader>ct :vsplit \| terminal claude<CR>

" ターミナルモードでのエスケープ
tnoremap <Esc> <C-\><C-n>

" ファイルパス・行番号コピー
nnoremap <leader>cp :let @+ = expand('%:p')<CR>:echo "Copied: " . expand('%:p')<CR>
nnoremap <leader>cl :let @+ = expand('%:p') . ':' . line('.')<CR>:echo "Copied: " . expand('%:p') . ':' . line('.')<CR>

" 選択範囲コピー
vnoremap <leader>cy "+y

" 読み取り専用モードトグル
nnoremap <leader>ro :set readonly!<CR>:echo "Read-only: " . (&readonly ? "ON" : "OFF")<CR>

" 差分表示
nnoremap <leader>df :DiffOrig<CR>
command! DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis

" Git関連
nnoremap <leader>gs :!git status<CR>
nnoremap <leader>gd :!git diff %<CR>
nnoremap <leader>gb :!git blame %<CR>

" プロジェクト管理
nnoremap <leader>pr :cd %:p:h<CR>:pwd<CR>
nnoremap <leader>rm :e README.md<CR>

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