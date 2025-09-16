" 軽量で便利な機能集

" 1. 高速な検索設定
set ignorecase  " 大文字小文字を無視
set smartcase   " 大文字が含まれる場合は区別
set incsearch   " インクリメンタルサーチ
nnoremap <leader>/ :nohlsearch<CR>  " 検索ハイライトを消す

" 2. 高速な移動
" 行頭・行末への移動
nnoremap H ^
nnoremap L $
" 次/前の空行へジャンプ
nnoremap } }zz
nnoremap { {zz

" 3. ウィンドウ操作の簡略化
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" 4. 保存の簡略化
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>

" 5. インデント保持した貼り付け
nnoremap p p`[v`]=
nnoremap P P`[v`]=

" 6. ビジュアルモードでの連続インデント
vnoremap < <gv
vnoremap > >gv

" 7. Yを行末までヤンクに
nnoremap Y y$

" 8. jkでESC（より速い）
inoremap jk <Esc>
inoremap kj <Esc>

" 9. 最後に編集した場所へジャンプ
nnoremap g; g;zz
nnoremap g, g,zz

" 10. ファイル名補完の改善
set wildmode=longest:full,full
set wildignore=*.o,*.obj,*~,*.pyc,*.pyo,*.swp,*.bak
set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/node_modules/*

" 11. 括弧の自動補完（Copilotとの競合を避けるため無効化）
" inoremap ( ()<Left>
" inoremap { {}<Left>
" inoremap [ []<Left>
" inoremap " ""<Left>
" inoremap ' ''<Left>

" 12. 行番号トグル
nnoremap <leader>n :set relativenumber!<CR>

" 13. バッファ操作
nnoremap <leader>] :bnext<CR>
nnoremap <leader>[ :bprevious<CR>
nnoremap <leader>d :bdelete<CR>

" 14. 日付挿入
nnoremap <leader>D "=strftime('%Y-%m-%d')<CR>p
inoremap <C-d> <C-r>=strftime('%Y-%m-%d')<CR>

" 15. sudo保存
command! W w !sudo tee % > /dev/null