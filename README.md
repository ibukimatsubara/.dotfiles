# Dotfiles

Modern, lightweight dotfiles for efficient development workflow.

## ✨ Features

- **🚀 Modern Neovim**: Lazy.nvim with image paste & inline preview + auto-reload
- **🖼️ Image Support**: Paste screenshots directly into Markdown with Kitty terminal
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
./install.sh  # Install required software
./setup.sh    # Configure dotfiles
```

**Two-step setup**: Install software first, then configure dotfiles.

### 📦 Installation Scripts

- **`install.sh`**: Installs all required software via Homebrew
  - Essential tools: Neovim, tmux, git
  - Image support: ImageMagick, luarocks
  - Fonts: JetBrains Mono Nerd Font
  - macOS tools: yabai, skhd, SketchyBar, JankyBorders
  - Optional: uv, nnn, Claude Code CLI

- **`setup.sh`**: Links configuration files and sets up dotfiles
  - Creates symlinks to configuration files
  - Sets up Zsh integration
  - Installs Neovim plugins
  - Configures macOS window management

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
- [codexbar](https://github.com/1vket/codexbar) (for AI usage display in tmux/SketchyBar)
- Docker, AWS CLI, Flutter, Poetry/uv

## 🎯 Key Features

### Neovim (Modern & Powerful)
- **Lazy.nvim**: Fast plugin manager with lazy loading
- **Image paste & preview**: Screenshots → Markdown with inline display
- **Auto-reload**: Files refresh automatically when changed by AI tools
- **GitHub Copilot**: AI-powered code completion
- **LSP + completion**: Intelligent code navigation (Python)
- **Hatsune Miku theme**: Beautiful cyan color scheme
- **10 carefully curated plugins**: Lightweight yet feature-rich

### Shell (Zsh)
- **AI Git commits**: `gcmc` (Japanese) / `gcmce` (English)
- **Smart aliases**: 50+ shortcuts for common operations
- **Custom prompt**: Real-time info without being cluttered

### tmux (Mouse-friendly)
- **Easy copy**: Mouse drag → automatic clipboard copy
- **Right-click paste**: Natural workflow
- **Session auto-save**: Resume your work after restart
- **Cross-pane selection**: Option+drag for terminal-style selection
- **AI usage display**: Shows Claude/Copilot usage in status bar (requires codexbar)

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

# Neovim image features (in Markdown files)
,p            # Paste screenshot from clipboard → saves to assets/
              # Automatically inserts Markdown link
              # Image displays inline in Kitty terminal!

# tmux copy
# Just drag with mouse → auto-copied!
# Right-click → paste
# Option+drag → select across panes
```

## 📁 Structure

```
.dotfiles/
├── install.sh               # Software installation script
├── setup.sh                 # Configuration setup script
├── nvim/                    # Neovim configuration
│   ├── init.lua            # Main entry point (Lazy.nvim)
│   ├── init.vim.backup     # Previous vim-plug config
│   ├── lua/
│   │   ├── config/         # Core settings
│   │   │   ├── options.lua
│   │   │   ├── keymaps.lua
│   │   │   └── autocmds.lua
│   │   └── plugins/        # Modular plugin configs
│   │       ├── colorscheme.lua  # Hatsune Miku theme
│   │       ├── git.lua          # vim-signify
│   │       ├── copilot.lua      # GitHub Copilot
│   │       ├── lsp.lua          # LSP + completion
│   │       ├── nvim-tree.lua    # File explorer
│   │       ├── bufferline.lua   # Tab line
│   │       ├── img-clip.lua     # Image paste
│   │       └── image.lua        # Image preview
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
    ├── neovim.md           # Neovim setup guide
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
- **Paste image**: `,p` (saves to assets/ and inserts Markdown link)
- **File path copy**: `<M-p>` (Option+P)
- **File explorer**: `<M-e>` (Option+E)
- **Claude Code**: `<M-c>` (Option+C for split)

## 🔧 Maintenance

### Update plugins
```bash
# Neovim (Lazy.nvim)
nvim
# Then in Neovim: :Lazy update

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

- **Neovim startup**: ~30-50ms (Lazy.nvim with lazy loading)
- **Zsh load time**: ~100ms (modular loading)
- **tmux responsiveness**: Optimized for real-time use
- **Memory usage**: Minimal footprint despite 10 plugins

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
- [Lazy.nvim](https://github.com/folke/lazy.nvim) by folke
- [img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim) by HakonHarnes
- [image.nvim](https://github.com/3rd/image.nvim) by 3rd

---

**Made with ❤️ and AI assistance**