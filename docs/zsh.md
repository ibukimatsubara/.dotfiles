# Zsh設定

このファイルはZshシェルの設定を管理します。

## 基本設定

### オプション
- `sharehistory`: コマンド履歴をセッション間で共有
- `auto_cd`: ディレクトリ名だけでcdを実行
- `correct`: コマンドのタイプミスを自動修正

### Node.js・Pythonの初期化

Node.jsのバージョン管理はfnmに統一します。`zsh/main.zsh` で `fnm env --use-on-cd --shell zsh` を読み込み、`.nvmrc` / `.node-version` があるディレクトリでは、その指定を使います。指定ファイルがないディレクトリでは直前の選択を維持し、新しいシェルではfnmの既定バージョンを使います。プロンプトのNode表示もfnmに対応し、表示のたびにバージョン管理ツールを呼び出しません。

古い `~/.zshrc` に残っている `nvm.sh` とnvm用bash completionの読み込みは削除します。通常のZsh補完は `zsh/configs/completion.zsh` で標準の `compinit` を読み込み、標準の権限チェックも維持します。HomebrewやローカルツールのPATH設定を先に行い、最後に `source ~/.dotfiles/zsh/main.zsh` を実行してください。後からHomebrewのPATHを先頭へ追加すると、fnmが選んだNodeよりHomebrewのNodeが優先されてしまいます。

移行前に `node --version`、`command -v node`、`npm --version` と使用中のグローバルCLIを確認します。使用中のNodeと同じバージョンをfnmへ導入し、`fnm default <version>` で既定値を合わせます。Nodeの保存先ごとにグローバルパッケージは分かれるため、使用中のCLIも引き継いでください。nvmの既存バージョンやパッケージは、移行が確認できるまで残しておけます。

Python用のpyenvは維持し、`~/.zshrc` の初期化に `--no-rehash` を付けます。

```zsh
eval "$(pyenv init --path --no-rehash)"
```

これにより、ターミナルを開くたびに実行ファイル一覧を再生成する処理を省きます。新しいPython CLIをインストールしてコマンドが見つからない場合は、`pyenv rehash` を手動で実行してください。Pythonのバージョン指定や既存の仮想環境は変更しません。

参照: [fnm](https://github.com/Schniz/fnm)、[pyenv init](https://github.com/pyenv/pyenv/blob/master/COMMANDS.md#pyenv-init)。

### 起動時のMibukiロゴ

新しい対話ターミナルの最初のプロンプトの前に、Mibukiのアイコンを文字アートで表示します。
元画像は `mibuki-homepage/web/public/mibuki512.png` です。起動時はローカルファイルのみ参照し、通信や外部コマンドの実行はありません。
表示はUnicodeの点字文字で細かな輪郭を表現したD案です。

- 設定・文字アート: `zsh/configs/startup-banner.zsh`
- 再表示: `mibuki_banner`
- 無効化: `~/.zshrc.local` に `MIBUKI_BANNER=0` を設定
- 幅36列未満・高さ18行未満のターミナル、非対話シェル、`zsh -c` などのコマンド実行時は表示しません。
- `source ~/.zshrc` で設定を読み直しても、自動表示は同じシェル内で一度だけです。
- 色: ロゴは白、サービス名はシアン、DAU・加入数の値は緑、月額目安は金色、更新日時・未取得値はグレーです。古いキャッシュの注記はオレンジで表示します。
- 色を無効化: `~/.zshrc.local` に `MIBUKI_BANNER_COLOR=0` を設定するか、`NO_COLOR` を定義します。パイプ出力では自動的に色を付けません。

### このPCだけにサービス指標を表示

明示的に有効化したPCでは、ロゴの右側にサービス指標を表示します。幅が足りなければロゴの下へ移動し、高さも不足する場合は指標だけを表示します。
最初の対象はLangDictの昨日のDAU、サブスク加入数、加入数×月額基準料金（$4.99）の売上目安です。
売上目安は実際の今月の売上ではなく、年額プランも同じ基準料金で計算します。買い切り・無料トライアルはサブスク加入数へ加算しません。

通常の `setup.sh` では有効化しません。会社のPCで同じdotfilesを使っても、ローカル設定と有効化ファイルがなければ取得・表示とも実行しません。

必要なものはmacOSまたはsystemdを使うUbuntu、Python 3.9以上、Google Cloud CLI（`gcloud`）、対象のFirebase AnalyticsのBigQuery日次出力です。Googleアカウントには日次テーブルの参照とBigQueryジョブの実行権限が必要です。

1. `scripts/mibuki-metrics.config.example.json` を `~/.config/mibuki-metrics/config.json` にコピーし、接続先を設定します。
2. DAUはFirebase Analyticsの既存BigQuery日次出力を使います。設定の `reporting_timezone` はAnalyticsのレポート日付に合わせます。`is_active_user` が真の一意な `user_pseudo_id` を集計するため、GA4のレポートのユーザー同定・モデリングによって画面上のDAUと差が出ることがあります。
3. 加入数はRevenueCat API v2の `active_subscriptions` を使います。必要権限は `charts_metrics:overview:read` のみです。V2 Secret API Keyを環境変数 `REVENUECAT_API_KEY` へ設定します。ローカルの `~/.config/mibuki-metrics/secrets.env` にexport定義を置き、`~/.zshrc.local` と更新スクリプトから読み込みます。ファイルの権限は600にし、キーと実際のproject IDはリポジトリへ保存しません。環境変数がない場合は、設定の `api_key_file` も利用できます。
4. `bash scripts/setup-mibuki-metrics.sh --enable` で、このPCに自動更新を登録します（macOSはLaunchAgent、Ubuntuはsystemdユーザータイマー）。

初回のローカル設定ファイルを用意します。既存のファイルがある場合はコピーで上書きせず、そのファイルを編集してください。

```bash
umask 077
mkdir -p ~/.config/mibuki-metrics
cp -n ~/.dotfiles/scripts/mibuki-metrics.config.example.json ~/.config/mibuki-metrics/config.json
touch ~/.config/mibuki-metrics/secrets.env
chmod 700 ~/.config/mibuki-metrics
chmod 600 ~/.config/mibuki-metrics/config.json ~/.config/mibuki-metrics/secrets.env
```

`config.json` では、Firebaseのproject ID、Analyticsのdataset ID（`analytics_<GA4 property ID>`）、BigQueryのロケーション、レポートのタイムゾーン、月額基準料金、RevenueCatのproject IDを設定します。RevenueCatのproject IDはダッシュボードのProject settingsにある、REST API v2用の `proj...` の値です。BigQueryは1日分の必要な列だけを集計し、既定では1回の処理量を10 MiBに制限します。

RevenueCatでは対象プロジェクトのAPI keys → New secret API keyでV2を選び、Charts metrics permissions → Overview ConfigurationだけをRead onlyにします。生成したキーをローカルの `secrets.env` に保存します。以下は書式の例であり、`YOUR_V2_SECRET_API_KEY` は実際のキーに置き換えます。

```bash
export REVENUECAT_API_KEY='YOUR_V2_SECRET_API_KEY'
```

更新スクリプトは `secrets.env` を自動で読み込みます。対話シェルでも同じ環境変数を使う場合は、次の行を `~/.zshrc.local` に追加します。

```zsh
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/mibuki-metrics/enabled" && -f "${XDG_CONFIG_HOME:-$HOME/.config}/mibuki-metrics/secrets.env" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/mibuki-metrics/secrets.env"
```

Google認証がまだなければ `gcloud auth login` を実行し、設定後に `bash ~/.dotfiles/scripts/setup-mibuki-metrics.sh --enable` で有効化します。

```bash
# 手動更新（今日すでに取得できた項目も更新）
bash ~/.dotfiles/scripts/mibuki-metrics.sh --force

# キャッシュの内容を表示（通信しない）
bash ~/.dotfiles/scripts/mibuki-metrics.sh --render

# このPCで取得・表示を無効化（認証・キャッシュは保持）
bash ~/.dotfiles/scripts/setup-mibuki-metrics.sh --disable
```

- 更新（macOS）: ログイン時と、起きている間の15分ごとの確認。スリープ中は起こさず、復帰後にlaunchdが確認を再開します。成功した項目はレポート日付のタイムゾーンで1日1回だけ取得します。
- 遅延・失敗（macOS）: 日次出力がまだない、オフライン、認証失敗などの場合は以前の成功値を保持し、15分ごとに未取得項目だけ再試行します。古い日の値は日付・`cached` で区別し、未取得値は `--` と表示します。
- キャッシュ: `~/.local/share/mibuki-metrics/snapshot.json`、表示用 `panel.txt`。保存内容は集計値と日時のみです。
- ログ: `~/.local/state/mibuki-metrics/refresh.log`。サービス名と固定エラーコードのみを記録し、APIレスポンスやトークンは記録しません。
- 認証: GoogleはこのPCの既存 `gcloud` ログインを再利用します。個人認証情報・キー・設定・集計値はdotfilesの外に置き、ディレクトリは700、ファイルは600で保護します。
- 定義: `launchd/com.local.mibuki-metrics.plist`。利用PCの絶対パス・XDG設定は有効化時にローカルのplistへ反映します。
- 拡張: ローカル設定の `services` 配列へ同じ形式でサービスを追加します。
- XDG: `XDG_CONFIG_HOME`、`XDG_DATA_HOME`、`XDG_STATE_HOME` を指定した場合は、それぞれの `mibuki-metrics/` 配下を利用します。
- 一時的な表示停止: `~/.zshrc.local` に `MIBUKI_METRICS=0` を設定します。日次更新は継続します。

#### Ubuntuで使う

接続先と認証情報は上記と共通です。`--enable` は
`~/.config/systemd/user/mibuki-metrics.service` と `mibuki-metrics.timer`
（XDG_CONFIG_HOME指定時はその配下）を生成します。毎日ローカル時刻の0時に1回更新します。
停止中に予定時刻を過ぎた場合は、次のログイン・復帰後に補完します。
15分ごとの確認・再試行は行わず、取得失敗時はキャッシュを保持して翌日の更新を待ちます。
スリープ中は起こしません。
Google Cloud CLIは `~/.local/bin` と `~/google-cloud-sdk/bin` も検索します。

```bash
bash ~/.dotfiles/scripts/setup-mibuki-metrics.sh --enable
systemctl --user status mibuki-metrics.timer
# 初回取得をすぐ実行
systemctl --user start mibuki-metrics.service
# 起動エラーの確認（取得処理のログはrefresh.log）
journalctl --user -u mibuki-metrics.service -n 20
```

`--disable` はタイマーとサービスを停止して登録を削除します。
接続設定・認証情報・キャッシュは保持します。
検証: `python3 scripts/test-mibuki-metrics-setup.py`。

#### プロジェクトを追加する

ローカルの `config.json` にある `services` 配列へ、既存のLangDict設定と同じ形式のオブジェクトを追加します。配列の順番が表示順です。`id` は重複しない小文字・数字・ハイフンの識別子、`name` は表示用のASCII文字列（24文字以内）にします。

RevenueCatのキーはプロジェクトごとに分け、`api_key_env` で読み込む環境変数名を指定します。例えば2つ目のプロジェクトは、接続情報を埋めた次のオブジェクトを `services` の2件目に追加します。

```json
{
  "id": "another-app",
  "name": "Another App",
  "reporting_timezone": "Asia/Tokyo",
  "monthly_price_usd": "2.99",
  "analytics": {
    "source": "bigquery",
    "project_id": "YOUR_SECOND_FIREBASE_PROJECT",
    "dataset_id": "analytics_YOUR_SECOND_GA4_PROPERTY_ID",
    "location": "US",
    "maximum_bytes_billed": 10485760
  },
  "revenuecat": {
    "project_id": "projYOUR_SECOND_REVENUECAT_PROJECT_ID",
    "api_key_env": "REVENUECAT_ANOTHER_APP_API_KEY"
  }
}
```

同じローカルの `secrets.env` に、2つ目のキーのexport定義を追加します。

```bash
export REVENUECAT_ANOTHER_APP_API_KEY='YOUR_SECOND_V2_SECRET_API_KEY'
```

追加後は `bash ~/.dotfiles/scripts/mibuki-metrics.sh --force` で取得し、新しいターミナルを開くか `mibuki_banner` で表示します。取得失敗時は `refresh.log` の該当プロジェクトのエラーコードを確認してください。プロジェクト追加だけならLaunchAgentの再登録は不要です。

参照: [GoogleのBigQuery Exportスキーマ](https://support.google.com/analytics/answer/7029846?hl=en)、[RevenueCat Charts & Metrics API](https://www.revenuecat.com/docs/api-v2/charts-and-metrics)。

検証: `python3 scripts/test-mibuki-metrics.py`、`bash -n scripts/mibuki-metrics.sh scripts/setup-mibuki-metrics.sh`、`zsh -n zsh/configs/startup-banner.zsh`、`plutil -lint launchd/com.local.mibuki-metrics.plist`。

macOSの `Last login` とローカルメール通知を非表示にするには `touch ~/.hushlogin` を実行します。
`~/.zshrc` にSSH鍵の読み込みがある場合は `ssh-add -q <鍵ファイル>` とすると、成功通知だけを抑制できます。

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
