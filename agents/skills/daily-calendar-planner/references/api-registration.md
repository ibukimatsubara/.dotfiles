# Google Calendar API registration

The only account is `ibuuun1224@gmail.com`. The only destination is the `AI Daily Plan` secondary
calendar created by this app. Never use Notion Calendar UI, Google Calendar UI imports, company OAuth
credentials, or a primary calendar as a write path.

## Verified connection

As of 2026-09-06, initial setup is complete. Reuse the existing client, token and calendar configuration
in `~/.config/daily-calendar-planner/`. Google Cloud uses project `mibuki-core` and service
`calendar-json.googleapis.com`; the OAuth consent branding is the existing “Mibuki Inbox Agent”, while
the dedicated client is “Daily Calendar Planner Desktop”. Only the three requested scopes were granted.
Seven events for 2026-09-07 08:00 were registered and verified; an identical retry inserted zero events.
The revised break-spacing plan was also applied on 2026-09-06: two entries updated, seven verified,
zero inserted; an identical retry updated zero entries. Breaks are now 12:00–14:00 and 16:00–18:00.
The initial read-back required normalizing omitted `transparency` to Google’s `opaque` default; this
is covered by a regression test. There are 29 passing local tests, including minimum break duration and spacing regressions. The last registration receipt is
`~/.config/daily-calendar-planner/last-registration.json`.

## Initial setup (only if missing)

- Enable Calendar API in the personal Cloud project `mibuki-core`.
- Create a dedicated Desktop OAuth client named `Daily Calendar Planner Desktop`.
- Store its downloaded JSON in `~/.config/daily-calendar-planner/client.json` with mode 0600.
- Obtain consent for `calendar.app.created`, `openid`, and `userinfo.email` only. This verifies the exact
  account and limits Calendar access to secondary calendars created by the app. Do not request broad
  Calendar permissions. Do not reuse Gmail tokens or extract browser session tokens.
- Complete the account's real Google consent flow. Tokens stay outside repositories, mode 0600.

Run the script with `uv run <absolute script path>` so inline dependencies are installed:

```bash
uv run "$HOME/.agents/skills/daily-calendar-planner/scripts/calendar_api.py" auth --client ~/.config/daily-calendar-planner/client.json
uv run "$HOME/.agents/skills/daily-calendar-planner/scripts/calendar_api.py" init-calendar
```

## Registration

First read the actual Notion Calendar and generate the plan normally. Resolve planning warnings before
registration. Feed the in-memory plan to `preview --plan -` and `apply --plan -` via stdin; do not save
private fixed events in an input file. Generated-event API previews may be saved for review.

The writer verifies the authenticated email before Calendar requests. It writes generated intervals only,
with stable IDs, private visibility, no attendees, disabled reminders, and sendUpdates=none. Every inserted
or already-present event is read back and compared. Repeating an identical plan should insert zero events.

Ordinary `apply` refuses differing events. For an explicitly requested revision, `update` supports the same
event-ID set only. It compares every existing event against the previous verified generated-event preview
(or the exact original preview previously verified on registration) before any write. Never obtain this
baseline by copying the current server events, because that would accept manual edits as planner output.
Manual edits, missing events, additional events, or changes in event count cause a stop. Do not change IDs
to bypass this check. Started events cannot be written or updated.

```bash
uv run "$HOME/.agents/skills/daily-calendar-planner/scripts/calendar_api.py" update \
  --plan - --previous-events "$HOME/.config/daily-calendar-planner/verified-events-2026-09-07.json"
```

Feed the new plan through stdin. The update uses conditional PATCH requests with `If-Match` ETags,
`sendUpdates=none`, and the same private destination. If concurrent edits produce HTTP 412, stop and
inspect; do not force an overwrite. Read all events back after writing. An interrupted update can be retried
with the original baseline: entries already matching the new plan are skipped. There is no multi-event
transaction; report a partial failure and retry explicitly with the same revision. Deletion is unsupported.
Successful apply/update commands save generated-event snapshots and the receipt under
`~/.config/daily-calendar-planner/`, outside repositories.

API reference: [conditional modifications](https://developers.google.com/workspace/calendar/api/guides/version-resources)
and [event patch](https://developers.google.com/workspace/calendar/api/v3/reference/events/patch).
 A partial failed write can be retried with the identical plan; a calendar-creation timeout
leaves a pending marker and must be inspected before retrying, to avoid creating duplicate calendars.

The browser may be used for initial Google Cloud/OAuth setup and read-only verification, never as the
calendar registration mechanism. Report the actual inserted/verified count and distinguish local mock
validation from the first live API test.
