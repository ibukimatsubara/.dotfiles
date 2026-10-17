# Ubuntu Quickshell Desktop Implementation Plan

> Execute inline using superpowers:executing-plans. User authorized installation, configuration, and sudo on 2026-10-17.

**Goal:** Prepare an opt-in Hyprland session with DankMaterialShell (Quickshell), Vicinae, macOS-style application shortcuts, Japanese input, and desktop essentials.
**Architecture:** Keep GNOME available. Add explicit Ubuntu desktop install/setup commands; shared setup does not switch sessions. Use Ubuntu's Hyprland 0.53 configuration format and DMS's supported IPC, without importing latest Lua compositor configs. DMS owns the bar, notifications, audio UI and wallpaper UI; Vicinae owns the main launcher and clipboard history. hyprlock/hypridle provide locking independent of shell health.
**Tech Stack:** Bash, Hyprlang, JSON, DMS/QML, Python unittest, apt.
**Spec:** `docs/ubuntu-hyprland-plan.md` plus the user's Quickshell decision.

## Global constraints

- No password or private host/device information in repository files.
- Preserve GNOME, its input method and active remote connection; do not reboot/logout automatically.
- Use official DMS Ubuntu stable PPAs and Ubuntu compositor packages; no Caelestia git dependencies.
- Keep monitor overrides and mutable DMS settings outside tracked symlinks.
- Session startup must not globally enable desktop daemons under GNOME.

## Review focus

- App focus is confined to the active workspace; terminal always creates a new window.
- Re-running setup must preserve DMS user changes and local monitor overrides.
- No duplicate notification servers or clipboard histories.
- Config syntax matches installed Hyprland and is tested with a separate nested/headless instance where possible.
- Missing app executables, no matching window, and malformed compositor output fail clearly.

## Tasks

1. Write failing app-routing and isolated desktop setup tests.
2. Add explicit install/setup scripts, Hyprland config modules, application-routing and session-start helpers. Add DMS defaults, Japanese input, lock/idle, screenshot and launcher bindings.
3. Install dependencies and Vicinae; apply user settings with backups. Confirm desktop session entry exists without changing the running GNOME session.
4. Verify scripts, JSON, idempotence, Hyprland parser and DMS startup where possible. Review changes and document versions, shortcuts, activation and remaining real-session checks.

## Execution record

- Selected DMS: official stable Ubuntu 26.04 packages; Caelestia currently requires git Quickshell and more custom dependencies.
- Installed official PPA definitions before preparing the package transaction; apt simulation kept Hyprland at 0.53.3 and selected DMS 1.6.3 / Quickshell 0.3.2.

- Tasks 1–3 complete: six desktop tests pass; packages installed; live user settings linked/seeded; GNOME session retained. Vicinae installed to ~/.local without global input-injection permissions.
- Nested compositor smoke test rendered DMS and Vicinae, with no Hyprland config errors. Real login/physical keyboard/screen-share checks remain user-session checks.
- Review fixes: override inherited IBus variables, propagate DISPLAY/XAUTHORITY to activated apps, generate the final config include for XDG_CONFIG_HOME. Regression tests observed failing before fixes.
- DMS package globally enables its graphical-session unit; user-level mask keeps startup tied to the Hyprland supervisor instead.

- Task 4 complete for pre-login validation: 6 desktop tests, 9 existing platform tests, tmux watcher, shell/JSON checks and compositor parsing passed. Desktop installer re-run: 0 upgraded/new/removed, settings retained. Nested visual test confirmed full bar and Vicinae clipboard deeplink; all test desktop processes were stopped.
- Corrected clipboard deeplink after testing the live CLI: vicinae://launch/clipboard/history. Screenshot proof is under ~/.cache/dotfiles-hyprland-proof/.
- Remaining activation is a user-controlled logout/login; physical-session input, locking, and screen sharing remain manual checks. No driver change or reboot was performed.
