" 完全自動リロード機能

" リロード時にカーソル位置を維持
function! PreserveView()
    let l:save = winsaveview()
    silent! e!
    call winrestview(l:save)
endfunction

" 強制的な自動リロード
function! ForceAutoReload()
    if &buftype == '' && filereadable(expand('%'))
        " カーソル位置を保存してリロード
        let l:pos = getpos('.')
        let l:view = winsaveview()
        
        " ファイルをリロード
        silent! execute 'e!'
        
        " カーソル位置を復元
        call winrestview(l:view)
        call setpos('.', l:pos)
        
        " サイレントモードでなければ通知
        if !exists('g:auto_reload_silent') || !g:auto_reload_silent
            redraw
            echo "File auto-reloaded"
        endif
    endif
endfunction

" タイマーで定期的にチェック（200msごと - より頻繁に）
if has('timers')
    let g:checktime_timer = timer_start(200, 
        \ {-> execute('silent! checktime')}, 
        \ {'repeat': -1})
endif

" ファイル変更を検知したら即座にリロード
autocmd FileChangedShell * call ForceAutoReload()

" ファイルタイプ別の自動リロード設定
augroup AutoReloadFileTypes
    autocmd!
    " 特定のファイルタイプでより頻繁にチェック
    autocmd FileType javascript,typescript,python,go,rust
        \ setlocal updatetime=100
    " ログファイルは常に最新を表示
    autocmd BufRead,BufNewFile *.log 
        \ setlocal autoread | 
        \ setlocal updatetime=100
augroup END

" 変更通知をステータスラインに表示（laststatus=0でも表示）
function! FileChangedWarning()
    if &modified
        echohl WarningMsg
        echo "File has unsaved changes and was modified externally!"
        echohl None
    endif
endfunction

" 便利なコマンド
command! AutoReloadOn let g:auto_reload_enabled = 1 | echo "Auto reload enabled"
command! AutoReloadOff let g:auto_reload_enabled = 0 | echo "Auto reload disabled"
command! ReloadAll bufdo e!

" デバッグ用：リロードイベントの確認
command! CheckReloadEvents 
    \ echo "autoread: " . &autoread . 
    \ ", updatetime: " . &updatetime . 
    \ ", modified: " . &modified