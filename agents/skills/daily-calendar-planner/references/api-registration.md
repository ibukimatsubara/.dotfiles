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
The initial read-back required normalizing omitted `transparency` to Google’s `opaque` default; this
is covered by a regression test. There are 23 passing local tests, including minimum break duration and spacing regressions. The last registration receipt is
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

Existing differing or manually edited events cause a stop. Replacement/deletion and changed-plan
reconciliation are not implemented. Do not silently change an ID to get around that stop. Started events
cannot be written. A partial failed write can be retried with the identical plan; a calendar-creation timeout
leaves a pending marker and must be inspected before retrying, to avoid creating duplicate calendars.

The browser may be used for initial Google Cloud/OAuth setup and read-only verification, never as the
calendar registration mechanism. Report the actual inserted/verified count and distinguish local mock
validation from the first live API test.
