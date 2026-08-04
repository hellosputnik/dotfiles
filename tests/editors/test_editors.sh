#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# 1. Validate Vim configuration syntax and options
if command -v vim >/dev/null 2>&1; then
    vim -u vim/vimrc -e -s -c "q!"
fi

# 2. Validate Neovim Lua configuration syntax and non-interactive startup
if command -v nvim >/dev/null 2>&1; then
    if command -v luac >/dev/null 2>&1; then
        luac -p nvim/init.lua
    fi
    nvim --headless -u nvim/init.lua +qall
fi
