# SSH接続時にホスト名を表示する設定

## 方法1: SSH設定で環境変数を送信

`.ssh/config`の各ホスト設定に以下を追加：

```ssh
Host home
    HostName your-home-server.com
    User your-username
    # この環境変数を送信
    SetEnv SSH_HOST=home

Host lab
    HostName lab-server.com
    User your-username
    SetEnv SSH_HOST=lab
```

## 方法2: ローカル側の設定

`.zshrc`や`.bashrc`に以下を追加：

```bash
# SSH時に自動的にホスト名を設定
ssh() {
    if [[ "$1" =~ ^[^-] ]]; then
        # 最初の引数がホスト名の場合
        SSH_HOST="$1" command ssh "$@"
    else
        command ssh "$@"
    fi
}
```

## 方法3: サーバー側の設定

接続先サーバーの`.zshrc`に以下を追加：

```bash
# SSH接続元の情報から推測
if [ -n "$SSH_CLIENT" ]; then
    # IPアドレスから逆引きしてホスト名を取得
    SSH_FROM_IP=$(echo $SSH_CLIENT | awk '{print $1}')
    SSH_FROM_HOST=$(getent hosts $SSH_FROM_IP 2>/dev/null | awk '{print $2}')
    export SSH_HOST="${SSH_FROM_HOST:-$SSH_FROM_IP}"
fi
```

## 注意事項

- `SetEnv`は比較的新しいSSHの機能なので、古いバージョンでは使えない場合があります
- サーバー側で`AcceptEnv SSH_HOST`の設定が必要な場合があります