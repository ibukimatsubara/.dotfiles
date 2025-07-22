# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files for:
- **Neovim** - Text editor configuration with plugins
- **tmux** - Terminal multiplexer configuration
- **Zsh** - Shell configuration with aliases and settings

## Installation and Setup

The repository uses symlinks to configure the user's environment without modifying original locations.

### Setup Command
```bash
sh setup.sh
```

This script:
1. Appends sourcing of `~/.dotfiles/zshrc` to `~/.zshrc`
2. Creates necessary directories (`~/.config/nvim/`, `~/.config/nvim/dein/`, `~/.config/nvim/toml/`)
3. Creates symlinks:
   - `~/.config/nvim/init.vim` → `~/.dotfiles/init.vim`
   - `~/.tmux.conf` → `~/.dotfiles/tmux.conf`
4. Installs vim-plug for Neovim plugin management

## Repository Structure

```
.dotfiles/
├── init.vim          # Neovim configuration
├── tmux.conf         # tmux configuration
├── zshrc            # Zsh aliases and settings
├── coc-settings.json # CoC plugin settings
├── setup.sh         # Installation script
├── config/          # Additional configurations
│   └── tmux/
│       └── tmux.conf
├── docs/            # Documentation in Japanese
│   ├── neovim.md
│   ├── setup.md
│   ├── tmux.md
│   └── zsh.md
└── theme/           # Theme files
    └── simple
```

## Key Configuration Details

### Neovim (init.vim)
- Uses vim-plug for plugin management
- Configured with CoC (Conquer of Completion) for code completion
- Tab settings: 2 spaces, expandtab enabled
- Leader key set to `,`
- Requires manual plugin installation after setup: `:PlugInstall`

### Zsh (zshrc)
- Contains extensive aliases for common commands:
  - Git shortcuts (g, gst, ga, gc, gcm, etc.)
  - tmux shortcuts (t, tn, tk, tt, tl)
  - Docker Compose shortcuts (dc, dcu, dcd, etc.)
  - Python virtual environment shortcuts (va, vd, vc)
- Settings: auto_cd, correct, sharehistory

### tmux (tmux.conf)
- Custom configuration for terminal multiplexing
- Requires manual plugin installation after setup: `Prefix + I`

## Development Notes

- Documentation is primarily in Japanese
- The repository expects Nerd Font to be installed for proper icon display
- Configuration files use UTF-8 encoding
- Changes to configuration files require re-sourcing or restarting the respective applications