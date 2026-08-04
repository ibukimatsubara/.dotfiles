# Chrome / Vimium C

Chromeのユーザープロファイル全体は管理しません。Cookie、保存済みパスワード、履歴、ログイン状態はGitへ入れず、Chrome Syncまたは別の安全なバックアップで復元します。

## Vimium C

- Chrome Web Store ID: `hfjbmagddngcpeloejdejnfgbamkjaeg`
- バックアップ: `vimium-c.json`
- 復元: Vimium Cの`Extension options`を開き、ページ下部の`Import settings`からJSONを選ぶ

現在の主なカスタマイズ:

- `Ctrl+h/l`: 前・次のChromeタブ
- `Ctrl+j/k`: 600単位の高速スクロール
- `o`、`O`、`b`、`B`、`gs`の既定マッピングを解除
- Vimium C設定同期を有効化

Options画面にはGmail向けの除外ルール（`f j <c-j> K`）も表示されていましたが、エクスポートJSONには含まれていませんでした。復元後にこのルールが表示されることを確認します。

## インストール済み拡張機能の棚卸し

### 開発・操作

- Vimium C
- ChatGPT
- Claude
- ColorZilla
- Disable keyboard shortcuts
- Tampermonkey

### タブ管理

- Acid Tabs
- Auto Tab Discard
- Tab Wrangler

この3つは役割が重なるため、利用状況を確認してから整理します。拡張機能を削除するとローカル設定を失う場合があるため、自動削除はしません。

### 閲覧・買い物

- AdBlock
- Google Docs Offline
- Keepa
- nextpage
- Sakura Check Linker

TampermonkeyのユーザースクリプトはVimium Cのエクスポートには含まれません。必要ならTampermonkey側でも別途エクスポートします。
