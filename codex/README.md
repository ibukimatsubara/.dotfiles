# Codex CLI (legacy)

Global instructions (`AGENTS.md`), skills, and the status line snippet moved to
the [agent-env](https://github.com/ibukimatsubara/agent-env) repository on
2026-10-21. `setup.sh` no longer writes to `~/.codex` or `~/.agents`.

- `agents/` keeps the old custom agent definitions. They are not deployed.
- `remote-home-AGENTS.md` is linked to `~/AGENTS.md` on a remote Mac by
  `scripts/setup-open-local-sender.sh`. See
  [`remote-codex-preview.md`](../docs/remote-codex-preview.md).
