# Pomoru with Lofi Station alerts

Custom patch for upstream Pomoru v1.2.0 ([MIT license](UPSTREAM-LICENSE)). Work, short breaks, and long breaks
play a warning once when the countdown crosses 60 seconds, then a completion
sound at zero. Pausing does not trigger sounds. Completed sessions advance
to the next session and wait for Space to start it in manual mode. The
existing status JSON for Caelestia is preserved.

Defaults are work 50 minutes, short break 10 minutes, and long break 30
minutes, with a long break after every third work session. Auto-start is
disabled by default; `a` toggles it.

Run `bash scripts/install-pomoru.sh` from the dotfiles checkout. Requirements:
Rust/Cargo (tested with Rust 1.93.1), `curl`,
`patch`, `sha256sum`, and FFmpeg's `ffplay`. The installer downloads pinned,
checksum-verified upstream source, applies the patch, runs `cargo test --locked`,
and builds with `cargo build --release --locked`. An existing executable is
backed up once as `~/.local/bin/pomoru.upstream` before atomic replacement.
Restart any already running Pomoru to use the new executable.

## Restore after cloning or pulling dotfiles (Ubuntu)

```sh
cd ~/.dotfiles
sudo apt-get install build-essential pkg-config curl patch coreutils ffmpeg
# Install rustup first if it is not available: https://rustup.rs/
rustup toolchain install 1.93.1 --profile minimal
RUSTUP_TOOLCHAIN=1.93.1 bash scripts/install-pomoru.sh
"$HOME/.local/bin/pomoru"
```

`git pull` and the normal dotfiles setup do not rebuild the executable. Run
`install-pomoru.sh` explicitly after pulling changes to this profile. Sound
assets and the patch are included here; no Lofi Station checkout is required.
The installer preserves existing `config.toml` (including tasks) and
`alerts.toml`. Existing durations remain in `~/.config/pomoru/config.toml`;
edit them there after exiting an old running version to adopt the defaults.
On an existing installation, press `a` to select manual mode if it is still
set to auto; newly seeded settings default to manual mode.
Use `q` to exit a running old version before launching the new one.

For the Caelestia bar integration, follow the
[Ubuntu desktop setup](../../../docs/ubuntu-hyprland-plan.md#pomoruの導入と操作).
The timer exports the same status JSON as upstream Pomoru; this installer
does not install or switch your desktop shell.

To restore the executable backed up on the first install, exit Pomoru and run:

```sh
cp "$HOME/.local/bin/pomoru.upstream" "$HOME/.local/bin/.pomoru-restore"
mv "$HOME/.local/bin/.pomoru-restore" "$HOME/.local/bin/pomoru"
```

## Customize alerts

Edit `~/.config/pomoru/alerts.toml` (or `$XDG_CONFIG_HOME/pomoru/alerts.toml`)
to customize notification titles, messages, sound paths, or disable sound and
notifications separately. Relative audio paths resolve under that directory;
absolute paths and `~/` paths also work. Restart Pomoru to reload settings.
The installer seeds this file once, preserving later customizations. Pomoru's
normal settings and tasks remain in `config.toml` and do not overwrite alerts.

Sound files were copied unchanged from Lofi Station's
`lofi-web/public/sounds/`: `warning-beep.mp3` (0.32 seconds) and
`timer-complete.mp3` (5.016 seconds). Both work and break completion use the
same completion sound, as in Lofi Station.

Playback and desktop notifications run off the timer thread; missing audio,
a missing player, or an unavailable notification daemon do not stop the timer.
The sound files are installed in the Pomoru config directory, so Lofi Station
does not need to be running or remain at its original checkout path.

Verification on Linux:

```sh
bash -n scripts/install-pomoru.sh
python3 scripts/test-pomoru-alerts.py
# Also exercise a real two-minute timer through its one-minute warning:
python3 scripts/test-pomoru-alerts.py "$HOME/.local/bin/pomoru" --warning
```

The PTY check uses temporary settings and substitutes only the audio player
with an argument recorder, preserving your actual timer and settings.
