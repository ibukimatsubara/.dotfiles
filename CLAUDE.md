# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal dotfiles for macOS (with Ubuntu support in `install.sh`). Configs live here and are symlinked (or copied) into place by `setup.sh`.

- **VS Code** — primary editor (settings, keybindings, curated extension list)
- **tmux** — terminal multiplexer, plus many helper scripts (status line, project picker, pane summaries)
- **Zsh** — modular aliases, settings, and functions
- **Ghostty** — main terminal (shaders, wallpapers); Kitty is kept as a legacy config
- **Claude Code / Codex** — global instructions, custom agents, shared skills, status lines
- **macOS tooling** — skhd hotkeys, Hammerspoon (break timer), launchd agents
- **Neovim** — legacy Lua config with Lazy.nvim

## Setup Commands

```bash
./install.sh   # Install Homebrew/apt packages and core tooling (once per machine)
./setup.sh     # Create dirs, back up existing configs, link/sync everything
```

Both scripts should stay idempotent. Existing files are moved to `*.bak-YYYYMMDD-HHMMSS` before being replaced.

## Repository Structure

```
.dotfiles/
├── install.sh / setup.sh   # OS-detecting entry points
├── platforms/              # common / macos / ubuntu install, setup, and overrides
├── AGENTS.md               # Repo guidelines for Codex (and other agents)
├── claude/                 # Claude Code: CLAUDE.md (global), agents/, statusline-command.sh
├── codex/                  # Codex: AGENTS.md (global), agents/*.toml, statusline.toml
├── agents/skills/          # Shared Agent Skills for Claude Code and Codex
├── vscode/                 # settings.json, keybindings.json, extensions.txt
├── tmux/tmux.conf
├── zsh/                    # main.zsh, aliases/, configs/, functions/
├── ghostty/                # config, shaders/, wallpapers/
├── hammerspoon/, break-timer/  # Break timer (Hammerspoon + Ghostty shader)
├── launchd/                # macOS LaunchAgents (blocklist, taildrop, tmux pane summaries)
├── scripts/                # Utilities, tmux helpers, setup-*.sh, test-*.sh
├── nvim/                   # Legacy Neovim (init.lua, lua/, plugin/)
├── kitty.conf, kitty/      # Legacy Kitty config and color themes
├── skhdrc                  # macOS hotkeys
├── chrome/                 # Vimium C export
├── theme/simple            # Zsh prompt theme
└── docs/                   # Per-tool notes (mostly Japanese)
```

## Where Things Are Linked

| Source | Target |
|---|---|
| `zsh/main.zsh` | sourced from `~/.zshrc` |
| `tmux/tmux.conf` | `~/.tmux.conf` |
| `vscode/settings.json` + `platforms/<OS>/vscode-settings.json` | merged settings linked into VS Code User (rerun setup after editing) |
| `vscode/keybindings.json` | VS Code User keybindings (shared) |
| `ghostty/config` or `ghostty/config-linux` (common + OS includes) | `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config` |
| `hammerspoon/init.lua` | `~/.hammerspoon/init.lua` |
| `break-timer/config.lua` | `~/.config/break-timer/config.lua` |
| `skhdrc` | `~/.skhdrc` |
| `nvim/{init.lua,lua,plugin}` | `~/.config/nvim/` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` (symlink) |
| `claude/agents/` | `~/.claude/agents/` (copied) |
| `codex/AGENTS.md` | `~/.codex/AGENTS.md` (symlink) |
| `codex/agents/` | `~/.codex/agents/` (copied) |
| `agents/skills/` | `~/.agents/skills` (symlink); each listed skill is also copied to `~/.claude/skills/<name>` |
| `claude/statusline-command.sh` | `~/.claude/statusline-command.sh` |

Notes:
- `claude/agents/`, `codex/agents/`, and the Claude copies of shared skills are **copied, not symlinked**. Re-run `./setup.sh` after editing them.
- The list of shared skills copied into `~/.claude/skills/` is hardcoded in `link_ai_clis` in `platforms/common/setup.sh`. Update it when adding a skill.
- `~/.claude/settings.json` and `~/.codex/config.toml` are not tracked. Merge `codex/statusline.toml` into the Codex config by hand.

## Verification

- Shell scripts: `bash -n <script>`; tmux helpers have tests under `scripts/test-*.sh`.
- JSON: `jq empty vscode/settings.json vscode/keybindings.json chrome/vimium-c.json`
- Daily planner skill: `python3 -m unittest` in `agents/skills/daily-calendar-planner/scripts/`
- Reload changed configs (`tmux source ~/.tmux.conf`, `source ~/.zshrc`, reload Hammerspoon/skhd) to confirm they apply.

## Conventions

- Commits follow Conventional Commits with short scopes (e.g., `feat(tmux): ...`, `fix(planner): ...`).
- Never commit secrets or machine-specific values; use `~/.zshrc.local` and `$HOME` instead of hardcoded paths.
- Documentation in `docs/` is primarily Japanese.
- See `AGENTS.md` for detailed style and testing guidelines.
