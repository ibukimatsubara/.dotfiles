# Zsh設定

このファイルはZshシェルの設定を管理します。

## 基本設定

### オプション
- `sharehistory`: コマンド履歴をセッション間で共有
- `auto_cd`: ディレクトリ名だけでcdを実行
- `correct`: コマンドのタイプミスを自動修正

## エイリアス一覧

### 基本コマンド
- `c`: `clear` - 画面をクリア
- `ll`: `ls -l` - ファイル詳細表示
- `la`: `ls -a` - 隠しファイル含む表示
- `lla`/`lal`: `ls -la` - 詳細+隠しファイル表示

### tmuxショートカット
- `t`: `tmux` - tmux起動
- `tn`: `tmux new -s` - 新しいセッション作成
- `tk`: `tmux kill-session -t` - セッション削除
- `tt`: `tmux a -t` - セッションにアタッチ  
- `tl`: `tmux ls` - セッション一覧表示

### エディタ
- `v`: `nvim` - Neovim起動

### Git
- `g`: `git`
- `gst`: `git status -s` - 簡潔なステータス表示
- `ga`: `git add`
- `gc`: `git clone`
- `gcm`: `git commit -m`
- `gco`: `git checkout`
- `gb`: `git branch`
- `gpl`: `git pull origin`
- `gps`: `git push origin`

### Python仮想環境
- `va`: `source .venv/bin/activate` - 仮想環境有効化
- `vd`: `deactivate` - 仮想環境無効化
- `vc`: `python3 -m venv .venv` - 仮想環境作成

### その他のツール
- `j`: `julia` - Julia言語
- `sec`: `singularity exec --nv` - Singularityコンテナ実行
- `sb`: `singularity build` - Singularityイメージビルド

### AtCoder競技プログラミング
- `ac`: AtCoder新規コンテスト作成
- `at`: テストケース実行
- `as`: 解答提出

### Docker/Docker Compose
- `dc`: `docker-compose`
- `dcu`: `docker-compose up -d`
- `dcd`: `docker-compose down`
- `dcr`: `docker-compose restart`
- `dce`: `docker-compose exec`
- `dcl`: `docker-compose logs`
- `dclf`: `docker-compose logs -f`
- `dcb`: `docker-compose build`
- `dcub`: `docker-compose up --build`
- `dcp`: `docker-compose ps`

- `dk`: `docker`
- `dki`: `docker images`
- `dkc`: `docker container`
- `dkl`: `docker logs`
- `dklf`: `docker logs -f`
- `dkrm`: `docker rm`
- `dkrmi`: `docker rmi`
- `dkps`: `docker ps`
- `dkpsa`: `docker ps -a`
- `dkpsq`: `docker ps -q`
- `dkpsl`: `docker ps -l`

## プロンプトテーマ

テーマファイル（`theme/simple`）を読み込んでプロンプトの外観を設定します。