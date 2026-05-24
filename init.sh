#!/bin/bash

set -euo pipefail

# Run from the script's own directory so all relative source paths resolve
# correctly regardless of where the user invoked init.sh from.
cd "$(dirname "${BASH_SOURCE[0]}")"

source sh/common.sh

sync_bash() {
    safe_copy bash/bash_profile "$HOME/.bash_profile"
    safe_copy bash/bash_prompt "$HOME/.bash_prompt"
    safe_copy bash/bashrc "$HOME/.bashrc"
}

sync_vim() {
    safe_copy vim/vimrc "$HOME/.vimrc"
    safe_copy vim/vim "$HOME/.vim"
}

create_boot_link() {
    mkdir -p "$HOME/.local/bin"
    ln -sf "$PWD/docker/boot.sh" "$HOME/.local/bin/boot"
}

run_task "Synced" "shell-agnostic configurations" safe_copy sh/profile "$HOME/.profile"

run_task "Synced" "Bash configurations" sync_bash

if [ ! -f "$HOME/.bashrc.local" ]; then
    run_task "Created" "local overrides file: ~/.bashrc.local" touch "$HOME/.bashrc.local"
fi

run_task "Synced" "Readline configurations" safe_copy readline/inputrc "$HOME/.inputrc"

if command -v git > /dev/null; then
    run_task "Synced" "Git configurations" safe_copy git/gitconfig "$HOME/.gitconfig"

    if [ ! -f "$HOME/.gitconfig.local" ]; then
        run_task "Created" "local git config: ~/.gitconfig.local" touch "$HOME/.gitconfig.local"
    fi

    # Prompt for git identity if not already set, and only when interactive
    # (skip in Docker builds and when stdin is piped).
    if [ -t 0 ] && [ "${DOCKER:-}" != "true" ]; then
        if [ -z "$(git config --global --includes --get user.name 2>/dev/null)" ] \
                || [ -z "$(git config --global --includes --get user.email 2>/dev/null)" ]; then
            ./git/git-init.sh
        fi
    fi
fi

if command -v rg > /dev/null; then
    run_task "Synced" "ripgrep configurations" safe_copy ripgrep/ripgreprc "$HOME/.ripgreprc"
fi

if command -v tmux > /dev/null; then
    run_task "Synced" "Tmux configurations" safe_copy tmux/tmux.conf "$HOME/.tmux.conf"
fi

if command -v vim > /dev/null || command -v nvim > /dev/null; then
    run_task "Synced" "Vim configurations" sync_vim
fi

if command -v nvim > /dev/null; then
    run_task "Synced" "Neovim configurations" safe_copy nvim "$HOME/.config/nvim"
fi

if [ -t 0 ] && [ "${DOCKER:-}" != "true" ]; then
    if command -v nvim > /dev/null; then
        run_with_spinner "Installing" "Installed" "Neovim plugins" nvim +PlugInstall +qall
    elif command -v vim > /dev/null; then
        run_with_spinner "Installing" "Installed" "Vim plugins" vim +PlugInstall +qall
    fi
fi

# Install the 'boot' launcher script only when running on the host machine.
# This avoids creating a broken symbolic link inside the Docker container environment.
if [ "${DOCKER:-}" != "true" ]; then
    run_task "Created" "launcher symlink: ~/.local/bin/boot" create_boot_link
fi

log_action "Finished" "dotfiles setup successfully"
