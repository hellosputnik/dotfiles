#!/bin/bash

# Define a robust copy function using rsync if available, falling back to cp.
# Usage: safe_copy "source_file" "destination_file"
safe_copy() {
    local source_file="$1"
    local destination_file="$2"
    local destination_directory=$(dirname "$destination_file")

    # Ensure the destination directory exists.
    mkdir -p "$destination_directory"

    if command -v rsync > /dev/null; then
        # -a: Enable archive mode (preserves timestamps and recursion).
        # -v: Enable verbose output.
        # -h: Enable human-readable format.
        # --no-perms: Do not strictly enforce permissions (useful when syncing across filesystems or users).
        rsync -avh --no-perms "$source_file" "$destination_file"
    else
        # Fallback to the standard cp command.
        # -R: Enable recursive copy.
        # -f: Force the copy.
        cp -Rf "$source_file" "$destination_file"
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
if command -v git > /dev/null
then
    safe_copy git/gitconfig "$HOME/.gitconfig"
fi

# Install Tmux configurations if Tmux is available.
if command -v tmux > /dev/null
then
    safe_copy tmux/tmux.conf "$HOME/.tmux.conf"
fi

# Install Vim configurations, plugins, and themes if Vim is available.
if command -v vim > /dev/null
then
    safe_copy vim/vimrc "$HOME/.vimrc"
    safe_copy vim/vim/ "$HOME/.vim"
fi

# Install Neovim configurations if Neovim is available.
if command -v nvim > /dev/null
then
    safe_copy nvim "$HOME/.config/nvim"
fi

# Install the 'boot' launcher script only when running on the host machine.
# This avoids creating a broken symbolic link inside the Docker container environment.
if [ "$DOCKER" != "true" ]; then
    mkdir -p "$HOME/.local/bin"

    # Resolve the absolute path of the 'docker/boot.sh' script.
    SCRIPT_PATH="$(cd "$(dirname "docker/boot.sh")" && pwd)/$(basename "docker/boot.sh")"
    ln -sf "$SCRIPT_PATH" "$HOME/.local/bin/boot"
fi