#!/bin/sh

echo "Please enter in your git username: "
read name
git config --global user.name "$name"

echo "Please enter in your git email address: "
read email
git config --global user.email "$email"

echo "Please enter in your preferred editor (e.g. vim, emacs, nano): "
read editor
git config --global core.editor "$editor"

