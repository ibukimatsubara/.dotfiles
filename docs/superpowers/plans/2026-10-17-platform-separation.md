# Platform Separation Implementation Plan

> Execute inline using superpowers:executing-plans.

**Goal:** Separate common, macOS, and Ubuntu configuration without changing the public setup commands.
**Architecture:** Shared functions and per-platform backends under `platforms/`; existing tool entry points load platform overrides.
**Tech Stack:** Bash, Zsh, tmux, Ghostty config, jq, Python unittest.
**Spec:** `docs/superpowers/specs/2026-10-17-platform-separation-design.md`

## Global Constraints

- Preserve macOS behavior and existing integration paths.
- Keep installation and linking repeatable and protect existing user settings.
- Do not run real package installations or desktop service restarts during testing.

## Review Focus

- Unsupported operating systems must fail before mutations.
- Profile selection must not load the other OS's desktop tools.
- Existing and already-linked VS Code settings must migrate without rewriting tracked JSON.
- Ghostty includes must resolve after setup, including XDG config locations.
- tmux automatic reload must still detect changes to its OS overlay.

## Tasks

1. Add `scripts/test-platform-config.py`; observe missing platform modules failing before implementation.
2. Extract install/setup behavior to `platforms/common`, `platforms/macos`, `platforms/ubuntu`. Keep root entry points as dispatchers with source guards. Add isolated detection and link/re-run tests.
3. Split Ghostty, tmux, Zsh, and VS Code settings; test both profile compositions and protect live user settings. Extend the tmux config watcher for its overlay.
4. Update README and setup/tool documentation. Run syntax/JSON checks, isolated integration tests, Ghostty validation, and relevant existing regressions. Review the final diff.

## Execution record

- User approved common/macOS/Ubuntu separation and requested implementation in this session.
- Work in the existing checkout to preserve the user's active repository path; do not move macOS application trees that contain established references.

- Tasks 1–4 complete: extracted install/setup backends, split application overrides, preserved integration paths, and documented migration.
- Verified: 9 platform tests; 9 desktop-theme tests; tmux watcher (main and overlay changes); project picker; Bash/Zsh syntax; managed JSON; Ubuntu Ghostty config validation; whitespace checks.
- Review: independent read-only review found no important regressions. Corrected Ghostty composition to use ordered includes from the existing entry files after checking the official include semantics.
- Ruling: make the existing project-picker permission test use the appropriate stat syntax on each OS; its former macOS-only stat command failed on Linux before this adjustment.
- Limit: macOS desktop UI and Ubuntu GUI key interactions require their respective real desktops. No package installation or desktop service restart was performed during tests.
