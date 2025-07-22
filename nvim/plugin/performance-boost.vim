" パフォーマンス最適化設定

" 描画の最適化
set lazyredraw          " マクロ実行中は再描画しない
set synmaxcol=200       " 長い行の構文解析を制限
set regexpengine=1      " 古い正規表現エンジン（高速）

" ファイルタイプ別の最適化
augroup performance_tweaks
    autocmd!
    " 大きなファイルでは一部機能を無効化
    autocmd BufReadPre * if getfsize(expand("%")) > 1000000 | 
        \ set syntax=off filetype=off |
        \ endif
    " ログファイルは構文解析なし
    autocmd BufRead *.log set syntax=off
augroup END

" アンドゥ履歴の永続化（軽量）
if has('persistent_undo')
    set undofile
    set undodir=~/.local/share/nvim/undo
    set undolevels=1000
    set undoreload=10000
endif

" セッション管理（シンプル版）
nnoremap <leader>ss :mksession! ~/.local/share/nvim/session.vim<CR>
nnoremap <leader>sl :source ~/.local/share/nvim/session.vim<CR>

" 高速スクロール
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

" マウスサポート（必要な場合）
set mouse=a

" より良い分割
set splitbelow
set splitright