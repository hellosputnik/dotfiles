#!/bin/sh

# Write to ~/.gitconfig.local so identity stays out of the dotfiles-tracked
# main gitconfig. The main gitconfig includes this file via [include].
LOCAL_CONFIG="$HOME/.gitconfig.local"

printf "Please enter in your git username: "
read -r name
git config --file "$LOCAL_CONFIG" user.name "$name"

printf "Please enter in your git email address: "
read -r email
git config --file "$LOCAL_CONFIG" user.email "$email"

printf "Please enter in your preferred editor (e.g. vim, emacs, nano): "
read -r editor
git config --file "$LOCAL_CONFIG" core.editor "$editor"
