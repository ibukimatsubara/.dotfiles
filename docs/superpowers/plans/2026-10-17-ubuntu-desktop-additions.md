# Ubuntu desktop additions

User approved proceeding while a physical Ubuntu login is unavailable. Preserve GNOME and system services; no logout or reboot.

## Implementation

1. Generate Hyprland, DMS and Vicinae colors from existing shared theme JSON; persist mutable settings and apply through session IPC. Use a stable generated Hyprland include before local overrides.
2. Add a persistent work/break timer and DMS widget. Session worker alone delivers sounds/notifications; CLI actions and status share locked state.
3. Add explicitly configured PipeWire input priorities. Empty defaults leave current input unchanged.
4. Add a DMS widget reading bounded local Codex rate-limit snapshots, without API or authentication access.
5. Link plugin code, seed local configuration and migrate bar entries once. Preserve later GUI choices. Scope all workers to the Hyprland supervisor.

Theme, timer and metrics/input backends were delegated independently; parent integrates widgets, setup, session and documentation.

## Validation

Use temporary HOME/XDG configuration and fake commands for selection, transitions, generation and migration tests. Confirm missing integration fails before implementing it. Run existing platform/theme tests and syntax checks. Launch a separate nested Hyprland under GNOME to verify plugin loading, theme IPC and drawing. Physical input, GPU, lock/resume and audio remain for the next real login.

## Result

Implemented all five steps. 47 Python tests pass, shell/JSON syntax and tmux watcher checks pass. Hyprland 0.53.3 verifies the real generated configuration. Nested runtime confirms both widget plugins, timer popout controls, shared wallpaper, DMS theme IPC and Vicinae theme IPC; screenshots and logs remain under `~/.cache/dotfiles-hyprland-proof/`. Found and fixed object-format widget duplication and Vicinae 0.29 theme data-directory discovery during review/runtime testing. No logout, reboot, physical microphone changes or system automation changes were performed.
