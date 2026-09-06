---
name: daily-calendar-planner
description: Read the actual Notion Calendar through Computer Use, adapt company work, personal activity and rest to the wake time, and open a read-only HTML day plan. Use for おはよう, 今日の計画, 明日の計画, or wake-time comparisons. Default to a dry run; register generated blocks through Google Calendar API only when requested.
---

# Adaptive daily planner

Canonical requirements: `~/life-kb/areas/life/2026-09-06-adaptive-daily-planning.md`.
Local preference update (2026-09-06, takes precedence over older requirements): generated breaks must
last at least 60 continuous minutes. Avoid clustered breaks: prefer at least two hours between breaks,
even when that requires moving personal activity earlier. Two hours is an adjustable spacing preference,
not a user-specified hard limit. Never fill an isolated 30-minute gap with a break; report unused capacity
or deficits instead. Retain four hours of total rest and the gym requirement when feasible.

Installed source: `~/.dotfiles/agents/skills/daily-calendar-planner`, exposed globally through
`~/.agents/skills`. Resolve scripts relative to this skill or the global path, never the working directory.
Output belongs to the active workspace. Credentials remain in `~/.config/daily-calendar-planner`.
The current workflow requires macOS, Notion Calendar, Computer Use, Python 3.11+ and uv. On a new machine,
restore the life-kb checkout and set up OAuth separately; dotfiles does not contain credentials.

Follow that repository's retrieval protocol. Its **現在の要件定義** takes precedence over historical
implementation notes. Read relevant current life/learning routine documents before assigning gym or tasks.

## One continuous run

1. Resolve the requested date in Asia/Tokyo. Default to today. Use the requested wake time; for a morning
   greeting use the current Japan time. A hypothetical future wake time must not be silently invented.
2. Use the available `computer-use` skill and `node_repl` + `@oai/sky` to read Notion Calendar.
   Start with `get_app_state({app:'com.cron.electron'})`. Display-name lookup has previously timed out
   while bundle-ID lookup worked. Retry once and inspect `list_apps` if connection fails.
3. Preserve the user's workspace. Before navigation, note the visible week/date, scroll position and any
   open event details in memory. **Use week view by default; do not routinely switch to day view.**
   Select the target date within week view and inspect event details for exact times. Only switch to day
   view temporarily if week view plus event details cannot provide reliable coverage. Recheck the date
   after any view switch, because Notion Calendar can reset it to today.
   Read all visible personal/company accounts, the all-day area, and the entire
   16-hour planning horizon by scrolling. For horizons crossing midnight, also read the next day.
   Open event details when needed to confirm exact start/end, ownership, busy/free and multi-day dates.
   Do not change hidden calendar visibility or import other people's hidden calendars by default.
4. Keep the observed events in memory. Record neutral categories and timezone-aware timestamps. Never
   save raw calendar trees, private titles, attendee lists or an event-input file. UI screenshot artifacts
   are tool-managed; do not make additional copies. An all-day event marked free is a reminder; a busy
   all-day event occupies its actual date interval. Never guess its duration or discard it.
Before allocation on an already-planned date, identify this app’s entries in the configured AI Daily Plan
calendar using the Calendar API and their private planner marker. Exclude verified, unchanged planner
entries from the fixed-event input to avoid counting the plan against itself. Do not identify ownership
by the title prefix alone. Treat manual edits as protected. On an explicit update request, use the guarded API update procedure
in references/api-registration.md; only an unchanged event-ID set is supported.

5. Send the JSON envelope below to `scripts/adaptive_day.py` via stdin (shell heredoc or transient
   subprocess input). The skill performs acquisition; the Python engine only allocates. A CLI run alone
   is not automatic calendar acquisition. Set `coverage_complete` only after the UI coverage was checked.
6. The engine preserves fixed times, counts company meetings within eight hours, allocates four hours of
   personal activity and two rest groups of two hours, then reports deficits and fixed overlaps. It minimizes
   deviation from the 4h/2h/4h/2h/4h rhythm. New durations use 30-minute multiples; fixed times remain exact.
   This is a capacity proposal, not a proven globally optimal timetable. If a constraint cannot fit, show
   the deficit and candidates to defer; do not call an infeasible plan complete.
7. Generate anonymized local review HTML under the active workspace's `output/daily-plans/`, then run
   `open -a 'Google Chrome' {absolute HTML path}`. Inspect the result through Computer Use. Display actual
   calendar events separately from generated work/rest. Briefly report the result and any assumptions.

Do not stop for a skeleton-only confirmation before calendar acquisition. Do not use the historical
`plan_day.py` rhythm/detailed modes for current daily requests: those modes predate the adaptive requirements.
If acquisition fails after retry/diagnosis, report a system connection failure; do not substitute a synthetic
fixture or require routine screenshot uploads or transcription. Synthetic data is only for explicit tests.

## Restore the calendar workspace

The owner uses week view and does not want the planner to leave the calendar in day view (2026-09-06).
After reading or verifying events, restore **week view**, the original visible week/date and scroll
position where feasible. Close only details or menus opened by this run; preserve pre-existing UI state
where possible. Do this before reporting completion, including on errors or partial failures. Use a
cleanup/finally step when automating multiple interactions. Inspect the resulting state and verify the
week view; do not claim restoration from a keypress alone. If the app cannot be reached after retry,
report that restoration could not be verified. Do not change calendar visibility, zoom, sidebar layout,
or other display preferences merely for convenience. A user's explicit request for a different final
view takes precedence.

## Engine input

```json
{
  "source": "notion-calendar",
  "date": "2026-09-07",
  "observed_at": "2026-09-06T15:00:00+09:00",
  "accounts_checked": ["personal-planning", "company", "personal-formal"],
  "coverage_complete": true,
  "coverage_start": "2026-09-07T00:00:00+09:00",
  "coverage_end": "2026-09-08T00:00:00+09:00",
  "events": []
}
```

This is a schema example, not actual acquisition. Each timed event has `start`, `end` (offset-aware ISO
strings), and `category` (`company`, `personal`, `fixed`, `commute`, `rest`). Optional `all_day: true` plus
`availability: "free"` records an unblocking reminder. Preserve all actual fixed intervals, including overlaps.
For confirmed MHI attendance only, include 08:00–09:00 and 17:00–18:00 as commute intervals, marked as
required constraints in the review. Do not infer attendance solely from Thursday/Friday. Fixed rest is
conservatively kept separate from discretionary rest and flagged for review.

```bash
uv run python "$HOME/.agents/skills/daily-calendar-planner/scripts/adaptive_day.py" \
  --date 2026-09-07 --wake 07:30 --gym \
  --output output/daily-plans/2026-09-07.html
```

`--gym` places a 90-minute all-inclusive gym proposal inside an eligible rest block; the remaining time
stays rest. Only use it for a gym day from the current routine. Shadowing uses the first 30 minutes of one
personal block, not an additional demand beyond the four-hour personal total. Meals can be annotated inside
rest; unresolved meal-window conflicts must be stated. Compare wake times with the same in-memory events.

## Boundaries

Notion Calendar navigation, scrolling, display changes and opening details are read-only operations.
Never create, edit, drag, resize, delete, duplicate or RSVP. Calendar registration must use `scripts/calendar_api.py`, never a browser import or Notion UI writes.
The owner authorized testing the 2026-09-07 08:00 plan through Google Calendar API on 2026-09-06.
OAuth setup and live registration succeeded on 2026-09-06 for the 2026-09-07 08:00 plan.
All seven generated events were read back successfully; an identical retry inserted zero events.
Notion Calendar also displayed AI Daily Plan and its synced events. Credentials and destination
configuration live in ~/.config/daily-calendar-planner; reuse them instead of repeating initial setup.
Use `references/api-registration.md` for connection, registration and verification. Do not claim the
connection or writes work until an actual API read-back succeeds. No background scheduling is installed.
