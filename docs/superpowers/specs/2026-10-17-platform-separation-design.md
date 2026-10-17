# macOS / Ubuntu platform separation

Keep one repository and the public `./install.sh` and `./setup.sh` commands. Automatically load common behavior followed by the detected macOS or Ubuntu profile. Debian remains compatible with the Ubuntu apt profile; unsupported systems fail before changing files or installing packages.

`platforms/common` owns shared shell helpers and install/setup functions. `platforms/macos` and `platforms/ubuntu` own package-manager behavior, desktop setup, and application overrides. Existing tool directories retain shared settings and established integration paths. macOS-only application directories (Hammerspoon, AeroSpace, SketchyBar) stay in place to preserve their internal path references, and are selected exclusively by the macOS setup module.

Ghostty uses a common config and two OS profiles; its old config paths remain entry files that include common then OS configuration, respecting Ghostty include ordering. Zsh loads common modules plus one OS module before local overrides and fnm initialization. tmux keeps common bindings, delegates clipboard handling to the portable helper, and loads an OS overlay before TPM. Keep existing status visibility on both systems. VS Code merges shared JSON with OS JSON into a generated file outside the repository and links User settings to it; setup backs up pre-existing settings and is repeatable. Re-run setup to apply JSON changes.

Do not install packages or restart desktop services on the working machine during verification. Exercise both profiles in temporary homes, with external commands stubbed where needed. Check shared keybindings, symlinks, settings composition, re-runs, unsupported OS handling, and existing tmux watcher reload behavior.
