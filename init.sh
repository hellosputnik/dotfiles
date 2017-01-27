#!/bin/bash

# Install bash configurations (bash_profile, bash_prompt, bashrc)
echo {_profile,_prompt,rc} | xargs -n 1 -I{} cp bash/bash{} ~/.bash{}

# Install tmux configurations
cp tmux/tmux.conf ~/.tmux.conf

# Install Vim configurations
cp vim/vimrc ~/.vimrc

# Install Vim plugins and themes
cp -fR vim/vim/ ~/.vim

