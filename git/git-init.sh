#!/bin/sh

# Write to ~/.gitconfig.local so user identity stays out of the tracked
# main gitconfig. The main configuration includes this file via [include].
LOCAL_CONFIG="$HOME/.gitconfig.local"

printf "Please enter your Git username: "
read -r name
git config --file "$LOCAL_CONFIG" user.name "$name"

printf "Please enter your Git email address: "
read -r email
git config --file "$LOCAL_CONFIG" user.email "$email"

printf "Please enter your preferred editor (e.g., vim, nano): "
read -r editor
git config --file "$LOCAL_CONFIG" core.editor "$editor"
