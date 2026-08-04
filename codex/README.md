# Codex CLI config

## statusline.toml

Reference snippet for the Codex TUI status line + terminal title, matching the
Claude Code statusline layout (`../claude/statusline-command.sh`).

Codex has **no external-command status line** like Claude Code — you pick from
predefined items. See [#17827 Customizable status line](https://github.com/openai/codex/issues/17827)
for a fully scriptable version.

### Applying

`~/.codex/config.toml` is machine-managed (Codex writes trust levels, plugin
hashes, MCP env, app version into it), so it is **not** symlinked. Merge the
`[tui]` block from `statusline.toml` into it by hand, or configure interactively:

```
/statusline        # run inside Codex — live preview + ordering
```

Then restart any running Codex session to pick up the change.
