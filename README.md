# Dotfiles

My personal dotfiles for macOS/Linux development environment.

## 🚀 Features

- **Modular Configuration**: Organized structure for easy maintenance
- **Minimal Neovim Setup**: Lightweight configuration with only essential plugins
- **Smart Shell Aliases**: Comprehensive aliases for Git, Docker, AWS, Flutter, and more
- **AI-Powered Git Commits**: Integration with Claude Code for intelligent commit messages
- **Auto-reload**: Neovim automatically reloads files changed by external tools
- **Beautiful Theme**: Hatsune Miku color scheme with transparent background

## 📦 Supported Tools

- **Shell**: Zsh with custom prompt and extensive aliases
- **Editor**: Neovim (minimal setup for performance)
- **Terminal**: tmux with custom key bindings
- **Version Control**: Git with AI-powered commit messages
- **Languages**: Python (Poetry/uv), Node.js, Flutter/Dart
- **Cloud**: AWS CLI with helpful aliases
- **Containers**: Docker & Docker Compose shortcuts

## 📋 Requirements

- Zsh
- Neovim (0.5+)
- tmux
- Git
- Nerd Font (for icons in prompt)
- curl (for installation)

Optional:
- Claude Code CLI (for AI commits)
- Docker
- AWS CLI
- Flutter
- Poetry/uv

## 🛠️ Installation

```bash
cd ~
git clone https://github.com/1vket/.dotfiles.git
cd .dotfiles
./setup.sh
```

The setup script will:
- ✅ Backup existing configurations
- ✅ Create necessary directories
- ✅ Install vim-plug for Neovim
- ✅ Create symlinks to dotfiles
- ✅ Install Neovim plugins automatically

## 📁 Structure

```
.dotfiles/
├── nvim/                   # Neovim configuration
│   ├── init.vim           # Main config (minimal)
│   ├── init.vim.backup    # Previous config backup
│   └── plugin/            # Additional features
│       ├── auto-reload.vim
│       ├── lightweight-features.vim
│       └── performance-boost.vim
├── zsh/                    # Zsh configuration
│   ├── main.zsh           # Entry point
│   ├── aliases/           # Categorized aliases
│   │   ├── common.zsh
│   │   ├── git.zsh
│   │   ├── docker.zsh
│   │   ├── aws.zsh
│   │   ├── flutter.zsh
│   │   └── python.zsh
│   ├── configs/           # Core settings
│   │   ├── settings.zsh
│   │   ├── theme.zsh
│   │   └── git-commit-lang.zsh
│   └── functions/         # Custom functions
│       ├── git-claude.zsh
│       └── ssh-wrapper.zsh
├── tmux/                   # tmux configuration
│   └── tmux.conf
├── theme/                  # Shell themes
│   └── simple             # Minimal prompt theme
└── docs/                   # Documentation (日本語)
```

## ⚡ Key Features

### Neovim
- **Ultra-light**: Only 2 plugins (colorscheme + git signs)
- **Auto-reload**: Files automatically refresh when changed externally
- **Smart keymaps**: Leader key shortcuts for common actions
- **Performance**: Optimized for large files

### Shell (Zsh)
- **AI Git commits**: `gcmc` generates commit messages using Claude
- **Language toggle**: `gcmc` (Japanese) / `gcmce` (English)
- **Smart aliases**: Short commands for common operations
- **Custom prompt**: Shows Git branch, SSH status, Python/Node environments

### Notable Aliases
```bash
# Git with AI
gcmc    # AI-generated commit message (Japanese)
gcmce   # AI-generated commit message (English)

# Quick navigation
v       # nvim
t       # tmux
g       # git
d       # docker

# Development
va      # activate Python venv
fl      # flutter
po      # poetry
```

## 🎨 Customization

### Change default commit language
Edit `~/.dotfiles/zsh/configs/git-commit-lang.zsh`:
```bash
export GIT_COMMIT_LANG="en"  # or "ja"
```

### Add custom aliases
Create `~/.zshrc.local` for personal additions.

### Neovim keymaps
- Leader key: `,`
- Save: `,w`
- Quit: `,q`
- Reload file: `,r`

## 🔧 Troubleshooting

### Neovim theme not showing
```bash
nvim
:PlugInstall
:source %
```

### Aliases not working
```bash
source ~/.zshrc
# or restart terminal
```

### Auto-reload not working
Check if `updatetime` is set:
```vim
:set updatetime?
```

## 📝 License

MIT

## 🙏 Acknowledgments

- [Hatsune Miku theme](https://github.com/4513ECHO/vim-colors-hatsunemiku)
- [vim-plug](https://github.com/junegunn/vim-plug)
- [Claude Code](https://claude.ai/code)