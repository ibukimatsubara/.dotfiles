# Claude Code config

## statusline-command.sh

Custom status line for Claude Code. Renders:

```
<dir> - [⬢node] - <branch/worktree> - <model> - ctx:NN%
```

Mirrors the `theme/simple` shell prompt. Worktree-aware: in a linked git
worktree it shows the worktree name instead of the branch.

### Wiring (handled by `setup.sh` → `link_ai_clis`)

`~/.claude/statusline-command.sh` is a symlink to this file, and
`~/.claude/settings.json` points at it:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

`settings.json` itself is not tracked (it holds per-account plugin/marketplace
state, and there are two accounts: `~/.claude` personal and `~/.claude-work`).
Only the statusLine script is version-controlled here.

Requires `jq`.
