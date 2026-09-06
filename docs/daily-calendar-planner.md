# Daily Calendar Planner

起床時刻と実際のカレンダーから、会社の仕事・自分の活動・休憩を組み立てる個人用Codexスキル。

## 配置と呼び出し

実体は `agents/skills/daily-calendar-planner/`。既存の `setup.sh` が
`~/.agents/skills` を `~/.dotfiles/agents/skills` にリンクするため、作業フォルダを問わず利用できる。
変更がスキル一覧に現れない場合はCodexを再起動する。

```text
$daily-calendar-planner 明日8時起きで計画を立てて
```

通常はHTMLプレビューのみ。登録を依頼した場合だけGoogle Calendar APIを使い、
`ibuuun1224@gmail.com` の専用 `AI Daily Plan` カレンダーへ登録する。
Notion Calendarは既存予定の読み取りに使い、登録操作には使わない。

## カレンダー表示の保持

Notion Calendarは週表示のまま読み取る。日表示が必要な場合も一時的に切り替えるだけにし、
終了時（エラー時を含む）は週表示へ戻す。元の表示週・スクロール位置も可能な範囲で復元する。
カレンダーの表示・非表示、ズーム、サイドバー配置などを都合で変更しない。

## 休憩のルール

- 休憩は1回につき最低60分。30分の空き時間を休憩で埋めない。
- 休憩間はなるべく2時間以上空ける。必要に応じて自分の活動を日中へ動かす。
- 2時間の間隔は配置上の優先条件で、固定予定は変更しない。
- 基準は会社8時間（会議込み）、自分の活動4時間、休憩4時間。
- 確保できない時間や休憩の密集は警告として表示する。ジムは休憩内の連続90分。

## ローカル依存と認証

macOS、Notion Calendar、CodexのComputer Use、Python 3.11以上、uvが必要。
生活ルールは `~/life-kb/areas/life/2026-09-06-adaptive-daily-planning.md` と関連文書を参照する。
別端末ではlife-kbとカレンダー接続を別途準備する。

OAuthクライアント・トークン・登録先設定は `~/.config/daily-calendar-planner/` に保存し、
dotfilesには含めない。レビューHTMLは実行時の作業フォルダの `output/daily-plans/` に保存する。

```bash
uv run "$HOME/.agents/skills/daily-calendar-planner/scripts/calendar_api.py" status
uv run python -m unittest discover \
  -s "$HOME/.agents/skills/daily-calendar-planner/scripts" -p 'test_*.py'
```

同じ計画の再登録は重複を作らない。通常の登録は既存予定との差分がある場合に停止する。
明示的に更新を依頼すると、前回登録済みの内容との一致を確認して同じIDの予定をAPI経由で更新する。
手動編集・予定の増減・同時編集を検知した場合は停止する。予定の削除は未対応。
ルール変更だけでは登録済み予定は変わらない。
