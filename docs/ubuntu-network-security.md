# Ubuntu の通信対策

開発中の通信を維持するため、対策を新規 TCP 受信の限定と受動監視に絞る。
パッケージ更新、アプリ・既存サービスの再起動、広い送信制限は行わない。

## 公開アドレスからの新規 TCP 受信

`platforms/ubuntu/systemd/ubuntu-ingress-guard.nft` は専用の nftables table だけを操作する。
loopback、`tailscale0`、既存接続、RFC1918 / link-local / ULA の送信元を維持し、残る新規 TCP を拒否する。
UDP、送信、Docker の forwarding、LAN 内通信は変更しない。
LAN 内の信頼制御や、すべての外部公開を防ぐ設定ではない。

`ubuntu-ingress-guard.service` と rule をそれぞれ `/etc/systemd/system/`、
`/etc/ubuntu-ingress-guard.nft` へ配置して専用 service だけを有効化する。
`nftables.service` は有効化しない。既定の `flush ruleset` で Docker / Tailscale の rule を消さない。
停止する場合は `sudo systemctl disable --now ubuntu-ingress-guard.service` でこの table だけを除く。

## 受動監視

`scripts/ubuntu-network-watch.py` を `~/.local/libexec/ubuntu-network-watch.py` に配置し、
`ubuntu-network-watch.service` と `.timer` を `~/.config/systemd/user/` に置く。
`systemctl --user enable --now ubuntu-network-watch.timer` で15分ごとに観察する。
必要なのは導入済みの `uv`、`/usr/bin/python3`、`ss`、Tailscale CLI だけ。
uv は offline、project discovery / Python download 無効で実行する。

以下の結果を `~/.local/state/ubuntu-network-watch/` の permission 600 の JSON に保存する。

- loopback 以外の TCP 待受。
- 現在のユーザーが動かす既知のトンネルの種類。生の引数や token は保存しない。
- この端末の Tailscale Funnel の設定。

最初は基準を作り、以後は直近1回の差分を `latest.json` で確認できる。
次回の成功で差分は上書きされる。user journal には変更・失敗が起きたことだけが残り、
詳細なイベント履歴の保持や自動アラートは行わない。
観察が失敗すると `status=unknown` を記録し、最後の成功結果を保持する。
root のトンネル、UDP、短時間の通信、独自実装や設定ファイル内の転送指定などを網羅しない。
検知に通信遮断・プロセス停止・popup を伴わせない。
停止は `systemctl --user disable --now ubuntu-network-watch.timer`。

```bash
systemctl --user status ubuntu-network-watch.timer
cat ~/.local/state/ubuntu-network-watch/latest.json
journalctl --user -u ubuntu-network-watch.service
uv run --offline --no-project --no-managed-python --python /usr/bin/python3 python -I scripts/test-ubuntu-network-watch.py
```
