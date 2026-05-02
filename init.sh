#!/bin/bash

set -euo pipefail

# Run from the script's own directory so all relative source paths resolve
# correctly regardless of where the user invoked init.sh from.
cd "$(dirname "${BASH_SOURCE[0]}")"

# Copy a file or directory; for directories, copies *contents* into destination.
# Usage: safe_copy <source> <destination>
safe_copy() {
    local source="$1"
    local destination="$2"

    if [ ! -e "$source" ]; then
        echo "safe_copy: source does not exist: $source" >&2
        return 1
    fi

    if [ -d "$source" ] && [ -e "$destination" ] && [ ! -d "$destination" ]; then
        echo "safe_copy: destination exists as a file but source is a directory; remove $destination manually" >&2
        return 1
    fi

    if [ ! -d "$source" ] && [ -d "$destination" ]; then
        echo "safe_copy: destination exists as a directory but source is a file; remove $destination manually" >&2
        return 1
    fi

    mkdir -p "$(dirname "$destination")"

    if [ -d "$source" ]; then
        mkdir -p "$destination"
        if command -v rsync > /dev/null; then
            # -a: Enable archive mode (preserves timestamps and recursion).
            # -v: Enable verbose output.
            # -h: Enable human-readable format.
            # --no-perms: Do not strictly enforce permissions (useful when syncing across filesystems or users).
            rsync -avh --no-perms "${source%/}/" "${destination%/}/"
        else
            # Fallback to the standard cp command.
            # -R: Enable recursive copy.
            # -f: Force the copy.
            cp -Rf "${source%/}/." "${destination%/}/"
        fi
    else
        if command -v rsync > /dev/null; then
            rsync -avh --no-perms "$source" "$destination"
        else
            cp -f "$source" "$destination"
        fi
    fi
}

# Install shell-agnostic configurations.
safe_copy sh/profile "$HOME/.profile"

# Install Bash-specific configurations.
safe_copy bash/bash_profile "$HOME/.bash_profile"
safe_copy bash/bash_prompt "$HOME/.bash_prompt"
safe_copy bash/bashrc "$HOME/.bashrc"

# Create a local override file if it does not exist.
if [ ! -f "$HOME/.bashrc.local" ]; then
    touch "$HOME/.bashrc.local"
fi

# Install Readline configurations.
safe_copy readline/inputrc "$HOME/.inputrc"

# Install Git configurations if Git is available.
if command -v git > /dev/null; then
    safe_copy git/gitconfig "$HOME/.gitconfig"

    # Create a local gitconfig override file if it does not exist.
    # The main gitconfig includes this file so machine-specific identity lives here.
    if [ ! -f "$HOME/.gitconfig.local" ]; then
        touch "$HOME/.gitconfig.local"
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

# Install ripgrep configurations if ripgrep is available.
if command -v rg > /dev/null; then
    safe_copy ripgrep/ripgreprc "$HOME/.ripgreprc"
fi

# Install Tmux configurations if Tmux is available.
if command -v tmux > /dev/null; then
    safe_copy tmux/tmux.conf "$HOME/.tmux.conf"
fi

# Install Vim configurations, plugins, and themes if Vim is available.
if command -v vim > /dev/null; then
    safe_copy vim/vimrc "$HOME/.vimrc"
    safe_copy vim/vim "$HOME/.vim"
fi

# Install Neovim configurations if Neovim is available.
if command -v nvim > /dev/null; then
    safe_copy nvim "$HOME/.config/nvim"
fi

# Install the 'boot' launcher script only when running on the host machine.
# This avoids creating a broken symbolic link inside the Docker container environment.
if [ "${DOCKER:-}" != "true" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$PWD/docker/boot.sh" "$HOME/.local/bin/boot"
fi
