#!/bin/bash

set -euo pipefail

# Run from the script's own directory so all relative source paths resolve
# correctly, regardless of the directory from which init.sh was invoked.
cd "$(dirname "${BASH_SOURCE[0]}")"

source sh/common.sh

sync_bash() {
    safe_copy bash/bash_profile "$HOME/.bash_profile"
    safe_copy bash/bash_prompt "$HOME/.bash_prompt"
    safe_copy bash/bashrc "$HOME/.bashrc"
}

sync_zsh() {
    safe_copy zsh/zprofile "$HOME/.zprofile"
    safe_copy zsh/zshrc "$HOME/.zshrc"
    safe_copy zsh/zsh_prompt "$HOME/.zsh_prompt"
}

sync_vim() {
    safe_copy vim/vimrc "$HOME/.vimrc"
    safe_copy vim/vim "$HOME/.vim"
}

create_boot_link() {
    mkdir -p "$HOME/.local/bin"
    ln -sf "$PWD/docker/boot.sh" "$HOME/.local/bin/boot"
}

# Install tmux plugins non-interactively (the equivalent of pressing prefix + I).
# TPM reads the plugin list from ~/.tmux.conf but resolves the clone directory
# from TMUX_PLUGIN_MANAGER_PATH in the tmux server environment. Both commands run
# as one sequence because a server started with no sessions exits as soon as it
# goes idle (exit-empty is on by default), which would race a second invocation.
# Any already-running server is reused and left otherwise untouched.
install_tmux_plugins() {
    tmux start-server \; set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins/"
    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

run_task "Installed" "~/.profile" safe_copy sh/profile "$HOME/.profile"
run_task "Installed" "~/.shellrc" safe_copy sh/interactive "$HOME/.shellrc"

if [ ! -f "$HOME/.profile.local" ]; then
    run_task "Created" "~/.profile.local" touch "$HOME/.profile.local"
fi

run_task "Installed" "Bash configurations" sync_bash

if [ ! -f "$HOME/.bashrc.local" ]; then
    run_task "Created" "~/.bashrc.local" touch "$HOME/.bashrc.local"
fi

run_task "Installed" "Zsh configurations" sync_zsh

if [ ! -f "$HOME/.zshrc.local" ]; then
    run_task "Created" "~/.zshrc.local" touch "$HOME/.zshrc.local"
fi

run_task "Installed" "~/.inputrc" safe_copy readline/inputrc "$HOME/.inputrc"

if command -v git > /dev/null; then
    run_task "Installed" "~/.gitconfig" safe_copy git/gitconfig "$HOME/.gitconfig"
    run_task "Installed" "~/.gitignore" safe_copy git/gitignore "$HOME/.gitignore"

    if [ ! -f "$HOME/.gitconfig.local" ]; then
        run_task "Created" "~/.gitconfig.local" touch "$HOME/.gitconfig.local"
    fi

    # Prompt for Git identity if it is not already set, and only in interactive sessions
    # (skipped in Docker builds and when standard input is piped).
    if [ -t 0 ] && [ "${DOCKER:-}" != "true" ]; then
        if [ -z "$(git config --global --includes --get user.name 2>/dev/null)" ] \
                || [ -z "$(git config --global --includes --get user.email 2>/dev/null)" ]; then
            ./git/git-init.sh
        fi
    fi
fi

if command -v rg > /dev/null; then
    run_task "Installed" "~/.ripgreprc" safe_copy ripgrep/ripgreprc "$HOME/.ripgreprc"
fi

if command -v curl > /dev/null; then
    run_task "Installed" "~/.curlrc" safe_copy network/curlrc "$HOME/.curlrc"
fi

if command -v wget > /dev/null; then
    run_task "Installed" "~/.wgetrc" safe_copy network/wgetrc "$HOME/.wgetrc"
fi

if command -v tmux > /dev/null; then
    run_task "Installed" "~/.tmux.conf" safe_copy tmux/tmux.conf "$HOME/.tmux.conf"
    if [ ! -f "$HOME/.tmux.conf.local" ]; then
        run_task "Created" "~/.tmux.conf.local" touch "$HOME/.tmux.conf.local"
    fi
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        run_task "Installing" "tmux plugin manager (tpm)" git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
    # Install the declared plugins, but only in interactive host sessions
    # (skipped in Docker builds and when standard input is piped). A failure here
    # is non-fatal: plugin cloning needs the network, and losing it should not
    # abort the remaining local setup steps.
    if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ] \
            && [ -t 0 ] && [ "${DOCKER:-}" != "true" ]; then
        run_with_spinner "Installing" "Installed" "tmux plugins" install_tmux_plugins || true
    fi
fi

if command -v vim > /dev/null || command -v nvim > /dev/null; then
    run_task "Installed" "Vim configurations" sync_vim
    if [ ! -f "$HOME/.vimrc.local" ]; then
        run_task "Created" "~/.vimrc.local" touch "$HOME/.vimrc.local"
    fi
    if [ ! -f "$HOME/.vimrc.bundles.local" ]; then
        run_task "Created" "~/.vimrc.bundles.local" touch "$HOME/.vimrc.bundles.local"
    fi
fi

if command -v nvim > /dev/null; then
    run_task "Installed" "~/.config/nvim" safe_copy nvim "$HOME/.config/nvim"
fi


if [ -t 0 ] && [ "${DOCKER:-}" != "true" ]; then
    if command -v nvim > /dev/null; then
        run_with_spinner "Installing" "Installed" "Neovim plugins" nvim +PlugInstall +qall
    elif command -v vim > /dev/null; then
        run_with_spinner "Installing" "Installed" "Vim plugins" vim +PlugInstall +qall
    fi
fi

if command -v brew > /dev/null; then
    run_task "Installed" "~/.Brewfile" safe_copy homebrew/Brewfile "$HOME/.Brewfile"

    if [ "${INSTALL_HOMEBREW_BUNDLE:-}" = "true" ]; then
        run_with_spinner "Installing" "Installed" "Homebrew bundle" \
            brew bundle --file "$HOME/.Brewfile" --no-upgrade
    fi
fi

if [ "${DOCKER:-}" != "true" ]; then
    mkdir -p "$HOME/.ssh/sockets"
    chmod 700 "$HOME/.ssh"
    chmod 700 "$HOME/.ssh/sockets"
    run_task "Installed" "~/.ssh/config" safe_copy ssh/config "$HOME/.ssh/config"
fi

# Install the boot launcher script only when running on the host machine.
# This prevents creating a broken symbolic link inside the Docker container.
if [ "${DOCKER:-}" != "true" ]; then
    run_task "Created" "~/.local/bin/boot" create_boot_link
fi

log_action "Finished" "dotfiles setup successfully"
