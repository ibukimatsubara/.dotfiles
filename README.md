# Dotfiles

Modern, lightweight dotfiles for efficient development workflow.

## ✨ Features

- **🚀 Ultra-fast Neovim**: Minimal setup with only 2 essential plugins + auto-reload
- **🤖 AI-Powered Git**: Intelligent commit messages with Claude Code integration  
- **🖱️ Smart tmux**: Mouse-friendly copy/paste + automatic session saving
- **⚡ Modular Zsh**: Organized aliases for Git, Docker, AWS, Flutter, Python
- **🎨 Beautiful Prompt**: Shows Git branch, SSH status, Node.js/Python environments
- **📁 Clean Architecture**: Well-organized, easy to maintain structure

## 🛠️ Quick Start

```bash
cd ~
git clone https://github.com/1vket/.dotfiles.git
cd .dotfiles
./setup.sh
```

**That's it!** The setup script handles everything automatically.

## 📋 Requirements

- **macOS/Linux**
- **Zsh** (default on macOS 10.15+)
- **Neovim** 0.5+
- **tmux**
- **Nerd Font** (for prompt icons)

### macOS Window Management (Optional)
- **yabai** (Tiling window manager)
- **skhd** (Hotkey daemon)
- **SketchyBar** (Custom menu bar)
- **JankyBorders** (Window borders)
- **SketchyVim** (Vim integration - planned)
- **nnn** (Terminal file manager - planned)

Optional for full features:
- [Claude Code CLI](https://claude.ai/code) (for AI commits)
- Docker, AWS CLI, Flutter, Poetry/uv

## 🎯 Key Features

### Neovim (Ultra-lightweight)
- Only 2 plugins: colorscheme + git signs
- **Auto-reload**: Files refresh automatically when changed by AI tools
- **Performance optimized**: Fast startup, handles large files
- **Hatsune Miku theme**: Beautiful cyan color scheme

### Shell (Zsh)
- **AI Git commits**: `gcmc` (Japanese) / `gcmce` (English)
- **Smart aliases**: 50+ shortcuts for common operations
- **Custom prompt**: Real-time info without being cluttered

### tmux (Mouse-friendly)
- **Easy copy**: Mouse drag → automatic clipboard copy
- **Right-click paste**: Natural workflow
- **Session auto-save**: Resume your work after restart
- **Cross-pane selection**: Option+drag for terminal-style selection

### macOS Window Management
- **yabai**: Tiling window manager for efficient workspace organization
- **skhd**: Keyboard shortcuts for window and application control
- **SketchyBar**: Custom menu bar with system information and controls
- **JankyBorders**: Beautiful window borders with customizable colors and styles
- **Planned additions**:
  - SketchyVim: Vim mode indicator integration
  - nnn: Fast terminal file manager

## 🔥 Notable Commands

```bash
# AI-powered Git commits
gcmc          # Generate commit message in Japanese
gcmce         # Generate commit message in English

# Quick shortcuts  
v file.txt    # Open in Neovim
t             # Start tmux
g st          # Git status
dk ps         # Docker ps
fl run        # Flutter run
po install    # Poetry install

# tmux copy
# Just drag with mouse → auto-copied!
# Right-click → paste
# Option+drag → select across panes
```

## 📁 Structure

```
.dotfiles/
├── nvim/                    # Neovim configuration
│   ├── init.vim            # Main config (minimal & fast)
│   └── plugin/             # Auto-reload & utilities
├── zsh/                     # Zsh configuration
│   ├── main.zsh            # Entry point
│   ├── aliases/            # Organized by tool
│   │   ├── git.zsh         # Git shortcuts + AI commits
│   │   ├── docker.zsh      # Docker & Docker Compose
│   │   ├── aws.zsh         # AWS CLI shortcuts
│   │   ├── flutter.zsh     # Flutter & Dart
│   │   └── python.zsh      # Poetry, uv, pip
│   ├── configs/            # Core settings
│   └── functions/          # AI commit functions
├── tmux/                    # tmux configuration
│   └── tmux.conf           # Mouse-friendly setup
├── sketchybar/              # SketchyBar configuration
│   ├── sketchybarrc        # Main config
│   ├── items/              # Bar items
│   └── plugins/            # Custom scripts
├── yabairc                  # yabai window manager config
├── skhdrc                   # skhd hotkey daemon config
├── bordersrc                # JankyBorders configuration
├── theme/                   # Shell themes
│   └── simple              # Minimal prompt with rich info
└── docs/                    # Documentation
    ├── sketchybar.md       # SketchyBar setup guide
    └── yabai-skhd.md       # Window management guide
```

## 🎨 Prompt Features

The prompt shows contextual information only when relevant:

```bash
# Basic
~/project - main ⚡

# With Python virtual environment  
~/project - .venv - main ⚡

# With Node.js project
~/project - ⬢16.14.0 - main ⚡

# SSH connection
◆ ~/project - main ⚡

# All together
◆ ~/project - .venv - ⬢16.14.0 - main ⚡
```

## 🤖 AI Git Commits

Generate intelligent commit messages using Claude Code:

```bash
git add .
gcmc    # Analyzes changes and generates Japanese commit
gcmce   # Generates English commit

# Example output:
# "feat: Neovimの自動リロード機能を追加"
# "fix: tmuxのマウスコピー問題を修正"
```

## ⚙️ Customization

### Change AI commit language default
```bash
# Edit ~/.dotfiles/zsh/configs/git-commit-lang.zsh
export GIT_COMMIT_LANG="en"  # or "ja"
```

### Add personal aliases
```bash
# Create ~/.zshrc.local
alias myalias="my command"
```

### Key bindings (Neovim)
- **Leader key**: `,`
- **Save**: `,w`
- **Quick escape**: `jk` or `kj`
- **File path copy**: `,cp`

## 🔧 Maintenance

### Update plugins
```bash
# Neovim
nvim +PlugUpdate +qall

# tmux
tmux run-shell ~/.tmux/plugins/tpm/bindings/install_plugins

# SketchyBar & JankyBorders (if using Homebrew)
brew upgrade sketchybar borders

# yabai & skhd
brew upgrade yabai skhd
```

### Restart services
```bash
# Restart window management and visual enhancements
brew services restart yabai
brew services restart skhd
sketchybar --reload
borders &

# Restart specific service
skhd --restart-service
yabai --restart-service
```

### Backup current setup
```bash
git add -A && git commit -m "backup: $(date)"
```

## 📊 Performance

- **Neovim startup**: ~50ms (2 plugins only)
- **Zsh load time**: ~100ms (modular loading)
- **tmux responsiveness**: Optimized for real-time use
- **Memory usage**: Minimal footprint

## 🎯 Philosophy

This dotfiles setup prioritizes:

1. **⚡ Speed**: Fast startup, minimal bloat
2. **🧠 Intelligence**: AI-powered workflows where helpful
3. **🎨 Beauty**: Clean, informative interfaces
4. **🔧 Maintainability**: Organized, documented, modular
5. **🚀 Productivity**: Shortcuts that actually save time

## 🙏 Acknowledgments

- [Hatsune Miku theme](https://github.com/4513ECHO/vim-colors-hatsunemiku) by 4513ECHO
- [Claude Code](https://claude.ai/code) by Anthropic
- [vim-plug](https://github.com/junegunn/vim-plug) by junegunn

---

**Made with ❤️ and AI assistance**