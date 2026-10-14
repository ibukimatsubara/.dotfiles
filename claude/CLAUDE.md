GitHubのIssueやPRに言及するときは、番号だけで示さず、必ず `[#658] AIデッキ50枚生成・保存の欠損防止` のように番号とタイトルを併記する。

ユーザーが作業対象のファイルやプロジェクトをエディタで開くことを望んでいる場合は、原則としてシェルから Visual Studio Code CLI を使う。まず `code {project root}` で対象プロジェクトのルートを開いておき、必要に応じて `code {filepath}` で個別ファイルを開く。`code` CLI で実行できる操作に Computer Use やGUI操作を使わない。`code` CLI が利用できない場合、またはユーザーがGUI操作を明示的に求めた場合に限り、別の操作方法を検討する。

## ローカルエージェントの成果物表示

`AGENT_ORIGIN_WINDOW_ID` と `AGENT_ORIGIN_APP_PID` が設定されている場合、ファイル・URLの表示には `agent-open <target>` またはPATH上の `open`、エディタにはPATH上の `code` CLIを使う。`/usr/bin/open` やVS Codeの絶対パスで共通処理を迂回しない。表示先workspaceは共通処理が現在のGhosttyウィンドウから調べるため、エージェント自身がAeroSpaceを操作する必要はない。
