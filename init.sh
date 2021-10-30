#!/bin/bash

# Install shell-agnostic configurations.
cp sh/profile $HOME/.profile

# Install bash-specific configurations.
cp bash/bash_profile $HOME/.bash_profile
cp bash/bash_prompt  $HOME/.bash_prompt
cp bash/bashrc       $HOME/.bashrc

# Install readline configurations.
cp readline/inputrc $HOME/.inputrc

# Install git configurations
if command -v git > /dev/null
then
    cp git/gitconfig $HOME/.gitconfig
fi

# Install tmux configurations
if command -v tmux > /dev/null
then
    cp tmux/tmux.conf $HOME/.tmux.conf
fi

# Install vim configurations, plugins, and themes.
if command -v vim > /dev/null
then
    cp vim/vimrc $HOME/.vimrc
    cp -fR vim/vim/ $HOME/.vim
fi

# Install nvim configurations
if command -v nvim > /dev/null
then
    mkdir -p $HOME/.config/nvim
    cp nvim/init.vim $HOME/.config/nvim/init.vim
fi

