#!/bin/bash

touch ~/.zshrc
echo "if [ -f ~/.dotfiles/zshrc ]; then" >> ~/.zshrc
echo "   . ~/.dotfiles/zshrc" >> ~/.zshrc
echo "fi" >> ~/.zshrc

# link
mkdir -p ~/.config/nvim
mkdir -p ~/.config/nvim/dein
mkdir -p ~/.config/nvim/toml
ln -s ~/.dotfiles/init.vim ~/.config/nvim/init.vim
ln -s ~/.dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/.dotfiles/dein.toml ~/.config/nvim/toml/dein.toml
ln -s ~/.dotfiles/dein_lazy.toml ~/.config/nvim/toml/dein_lazy.toml

sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
 https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

