#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# 1. Validate syntax for Bash, POSIX sh, and Zsh configuration files
bash -n \
    init.sh \
    bash/bash_profile \
    bash/bash_prompt \
    bash/bashrc \
    docker/boot.sh \
    git/git-init.sh \
    test.sh \
    tests/docker/test_docker.sh \
    tests/editors/test_editors.sh \
    tests/git/test_git.sh \
    tests/homebrew/test_brewfile.sh \
    tests/shell/test_bootstrap.sh \
    tests/shell/test_configuration.sh \
    tests/tmux/test_tmux.sh \
    tests/tools/test_tools.sh

/bin/sh -n \
    sh/common.sh \
    sh/interactive \
    sh/profile

if ! command -v zsh >/dev/null 2>&1; then
    printf 'zsh is required to validate configuration files.\n' >&2
    exit 1
fi

zsh -n \
    zsh/zprofile \
    zsh/zsh_prompt \
    zsh/zshrc

# 2. Check git for trailing whitespace or unresolved merge conflicts
git diff --check

# 3. Create a temporary sandbox home directory for profile & alias testing
temporary_directory=$(mktemp -d)
cleanup() {
    if [[ -n "${temporary_directory:-}" && -d "$temporary_directory" ]]; then
        rm -rf -- "$temporary_directory"
    fi
}
trap cleanup EXIT

temporary_home="$temporary_directory/home"
temporary_binary_directory="$temporary_directory/bin"
mkdir -p "$temporary_home/.local/bin" "$temporary_binary_directory"

# Create dummy binaries so alias detection logic can be tested
for command_name in bat fd nvim rmv; do
    touch "$temporary_binary_directory/$command_name"
    chmod +x "$temporary_binary_directory/$command_name"
done

# 4. Test that sourcing sh/interactive sets alias replacements cleanly across shells
for shell_executable in /bin/sh "$(command -v bash)" "$(command -v zsh)"; do
    HOME="$temporary_home" \
        PATH="$temporary_binary_directory:/usr/bin:/bin" \
        "$shell_executable" -c '
            . "$1"

            # Verify modern tool alias mappings
            alias vim | grep -q nvim
            alias rm | grep -q rmv

            # Ensure built-ins like cat and find are not shadowed by aliases
            if alias cat >/dev/null 2>&1; then
                printf "cat must not be aliased.\n" >&2
                exit 1
            fi
            if alias find >/dev/null 2>&1; then
                printf "find must not be aliased.\n" >&2
                exit 1
            fi
        ' dotfiles-test "$PWD/sh/interactive"
done

# 5. Verify that sourcing sh/profile multiple times does not duplicate PATH entries
HOME="$temporary_home" \
    PATH="$temporary_binary_directory:/usr/bin:/bin" \
    /bin/sh -c '
        . "$1"
        . "$1"

        # Count occurrences of ~/.local/bin in PATH
        local_binary_count=0
        old_ifs=$IFS
        IFS=":"
        for path_entry in $PATH; do
            if [ "$path_entry" = "$HOME/.local/bin" ]; then
                local_binary_count=$((local_binary_count + 1))
            fi
        done
        IFS=$old_ifs

        [ "$local_binary_count" -eq 1 ]
    ' dotfiles-test "$PWD/sh/profile"
