# tmux コピー操作ガイド

## マウスでのコピー方法

### 基本操作
1. **通常のマウスドラッグ**: tmuxのコピーモードで選択
2. **Optionキー + ドラッグ**: ターミナルの通常選択（iTerm2/Terminal.app）
3. **ダブルクリック**: 単語を選択
4. **トリプルクリック**: 行を選択

### コピー手順
1. マウスでテキストをドラッグ
2. 自動的にクリップボードにコピーされる
3. `Cmd+V` または tmux内で `Prefix + ]` でペースト

## Ghosttyでtmuxを使っていない場合

`ghostty/config` の `copy-on-select = clipboard` により、ドラッグで選択した文字はマウスを離すとmacOSのクリップボードへコピーされる。追加のコピー操作は不要で、`Cmd+V` で貼り付けられる。

Ghosttyの既定値 `true` は選択用クリップボードを優先するため、通常のクリップボードにもコピーする `clipboard` を明示している。tmux内の通常ドラッグは、既存のtmux設定がコピーを処理する。

設定を変更した場合はGhosttyの「Reload Configuration」を実行する。参考: [Ghostty公式設定リファレンス](https://ghostty.org/docs/config/reference#copy-on-select)。

## キーボードでのコピー方法

### コピーモードに入る
```
Prefix + [
```

### コピーモードでの操作
- `v`: 選択開始
- `V`: 行選択
- `y`: コピーしてコピーモード終了
- `Enter`: コピーしてコピーモード終了
- `q`: コピーモードを終了（コピーせず）

### 移動（Vimライク）
- `h,j,k,l`: 左下上右
- `w,b`: 単語単位で移動
- `0,$`: 行頭・行末
- `g,G`: ファイルの先頭・末尾

## セッション管理

### 手動保存・復元
- `Prefix + Ctrl-s`: セッション保存
- `Prefix + Ctrl-r`: セッション復元

### 自動保存
- 15分ごとに自動保存
- tmux起動時に最後のセッションを自動復元

## トラブルシューティング

### マウスコピーが効かない場合
1. tmuxを再起動: `tmux kill-server && tmux`
2. プラグインを再インストール: `Prefix + I`

### macOS以外の環境
`pbcopy`を適切なコマンドに置き換え：
- Linux: `xclip -selection clipboard`
- WSL: `clip.exe`
