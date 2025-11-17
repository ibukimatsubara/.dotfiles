# Repository Guidelines

## Project Structure & Module Organization
- `install.sh` and `setup.sh` are the entry points for installing packages and linking configs; keep them idempotent.
- `nvim/` holds Lua-based Neovim config (`lua/config`, `plugins`) with Lazy.nvim; `assets/` stores pasted screenshots referenced from Markdown.
- Shell settings live in `zsh/` (modular aliases and env), terminal/tabs in `tmux/`, and prompt/theme tweaks in `theme/`.
- macOS window management lives at `yabairc`, `skhdrc`, `sketchybar/`, and `bordersrc`; terminal defaults sit in `kitty.conf` and `alacritty.toml`.
- `docs/` contains setup notes for Neovim, SketchyBar, and yabai; `scripts/` offers utilities like backing up or restoring dotfiles.

## Build, Test, and Development Commands
- `./install.sh` — install Homebrew packages and core tooling (run once per machine).
- `./setup.sh` — create required directories, back up existing configs, and symlink everything into place.
- `nvim --headless "+Lazy sync" +qa` — ensure plugins install after Lua changes; add `:+CheckHealth` when debugging.
- `scripts/backup-existing-dotfiles.sh` — snapshot current dotfiles before experimental changes; pair with `restore-dotfiles.sh` to roll back.

## Coding Style & Naming Conventions
- Shell: Bash-first with readable helpers (e.g., `print_info`); keep function names snake_case and prefer clear emoji/status logs already used in scripts.
- Lua: two-space indentation, require modules via `require("config.*")`, and keep plugin specs lean inside `nvim/plugins` modules.
- File names should stay kebab-case for scripts and lowercase dotfile names matching upstream tools (`tmux.conf`, `kitty.conf`).

## Testing Guidelines
- After modifying scripts, run them with `bash -n` for syntax checks and exercise critical paths on macOS + Linux when relevant.
- For Neovim updates, open a Markdown file and verify image paste (` ,p `) writes to `assets/` and links render in Kitty; check key mappings from `config.keymaps`.
- Validate window-management tweaks by reloading services (`brew services restart yabai skhd` and `sketchybar --reload`) to catch missing permissions or paths.

## Commit & Pull Request Guidelines
- Follow Conventional Commit styles seen in history (`feat:`, `docs:`, `refactor:`); keep scopes concise (e.g., `feat: update tmux copy flow`).
- Commits should stay focused and runnable; include command outputs in the PR description when touching install/setup scripts.
- PRs: provide a short summary, list tested commands, note platform (macOS/Linux), and attach screenshots for UI changes (SketchyBar, borders, theme).

## Security & Configuration Tips
- Never commit machine-specific secrets or tokens; prefer `~/.zshrc.local` for private overrides and keep it out of git.
- Avoid hardcoding hostnames or user paths—lean on `$HOME` and tool defaults so `setup.sh` stays portable.
