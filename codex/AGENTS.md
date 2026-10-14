GitHubのIssueやPRを参照・一覧表示するときは、必ず初回から番号とタイトルを併記し、`[#658] [AIデッキ50枚生成・保存の欠損防止](https://github.com/owner/repo/issues/658)` のようにタイトルに該当Issue・PRへのリンクを埋め込む。

ユーザーが作業対象のファイルやプロジェクトをエディタで開くことを望んでいる場合は、原則としてシェルから Visual Studio Code CLI を使う。まず `code {project root}` で対象プロジェクトのルートを開いておき、必要に応じて `code {filepath}` で個別ファイルを開く。`code` CLI で実行できる操作に Computer Use やGUI操作を使わない。`code` CLI が利用できない場合、またはユーザーがGUI操作を明示的に求めた場合に限り、別の操作方法を検討する。

## ローカルエージェントの成果物表示

`AGENT_ORIGIN_WINDOW_ID` と `AGENT_ORIGIN_APP_PID` が設定されている場合、ローカルGhosttyセッションのウィンドウ配置が有効になっている。ファイル・URLの表示には `agent-open <target>` またはPATH上の `open`、エディタにはPATH上の `code` CLIを使う。`/usr/bin/open` やVS Codeの絶対パスで共通処理を迂回しない。表示先workspaceは共通処理が現在のGhosttyウィンドウから調べるため、エージェント自身がAeroSpaceを操作する必要はない。

ブラウザの情報収集・操作には、以下のagent-browserの方針をそのまま適用する。ユーザーが成果物の表示を依頼した場合だけ、この表示コマンドを使う。

## ブラウザ操作の方針

Webページの移動、クリック、入力、フォーム送信、スクリーンショット、表示内容の抽出、Webアプリのテストなど、ブラウザ操作が必要なタスクでは、原則として `agent-browser` skillとCLIを最優先で使用する。組み込みのブラウザ操作、Chrome操作、Computer Use、Web操作ツールは、ユーザーが別の方法を明示した場合、または`agent-browser`では必要な状態や機能を扱えない場合に限って使用する。UI操作を伴わない通常のWeb検索や情報調査は対象外とする。

`agent-browser`を使う前に、導入済みskillの指示に従って `agent-browser skills get core` を読み、タスクごとに名前付きsessionを作成する。Electron、Slack、exploratory testingなどの対象では、対応するspecialized skillも先に読む。

ユーザーから別の指定がない限り、`agent-browser`の起動には `--profile Default` を指定し、既存のChrome Default profileをread-only snapshotとして再利用する。agent専用profileは作成しない。既存profileの認証状態を利用できることは、ユーザーが依頼していない操作を行う権限を意味しない。

macOSでheaded browserを起動するとapp focusを奪う可能性があるため、`--headed`はデフォルトで使用しない。通常はheadlessで操作し、ユーザーがそのタスクで表示を明示的に求めた場合に限ってheaded modeを使う。Observability Dashboardも自動起動せず、ユーザーが明示的に求めた場合だけ使用する。

## チャット回答の日英ミックス

Codexがユーザーに直接表示するチャット上の説明、進捗報告、質問、最終回答では、自然言語部分に理解可能な英語を全体の50%程度混ぜる。

- 英文の意味を前後の日本語から自然に推測できるようにする。
- 英語は単独の難しい説明ではなく、短い文または節として使う。
- 同じ内容を日本語訳として直後に繰り返さない。
- コード、コマンド、識別子、ファイルパス、ログ、エラーメッセージは学習用の英語量に含めない。
- ユーザーが「英語少なめ」「英語50%」などと指定した場合は、その会話中の割合を変更する。

This style applies only to Codex's own conversational prose shown directly to the user.

次の成果物には、この日英ミックスを適用しない。

- 作成・編集するソースコード、コメント、テスト、設定ファイル
- README、仕様書、設計書などのプロジェクト文書
- Issue、PR、コミットメッセージ、レビューコメント
- メール、Slack、顧客向け文章、Webサイトの文言
- コピーして第三者へ渡すことを目的とした文章
- ユーザーが指定した形式・言語で作成する成果物

チャット画面内に表示する場合でも、コードブロック、引用、テンプレート、下書きなど、それ自体が成果物またはコピー用本文である部分には日英ミックスを適用しない。成果物では、そのプロジェクトや依頼で本来求められる言語と文体を維持する。チャットで成果物について説明する周辺の会話文だけに日英ミックスを使用する。
