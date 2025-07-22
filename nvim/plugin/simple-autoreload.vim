" シンプルで確実な完全自動リロード

" 外部変更時は問答無用でリロード
set autoread
set noswapfile

" FileChangedShell の自動コマンドを削除（プロンプトを無効化）
autocmd! FileChangedShell *

" タイマー用の関数（先に定義）
function! s:CheckAndReload(timer)
    if mode() == 'n' && &buftype == ''
        silent! checktime
    endif
endfunction

" 独自の自動リロード実装
augroup SimpleAutoReload
    autocmd!
    " ファイル変更検知時に即座にリロード
    autocmd CursorHold,CursorHoldI,BufEnter,FocusGained * 
        \ if &buftype == '' |
        \   silent! checktime |
        \   if v:fcs_reason == 'changed' || v:fcs_reason == 'time' |
        \     let view = winsaveview() |
        \     silent! edit |
        \     call winrestview(view) |
        \   endif |
        \ endif
    
    " タイマーで継続的にチェック（100ms間隔）
    if has('timers') && !exists('g:autoreload_timer')
        let g:autoreload_timer = timer_start(100, function('s:CheckAndReload'), {'repeat': -1})
    endif
augroup END

" 通知を最小限に
set shortmess+=F