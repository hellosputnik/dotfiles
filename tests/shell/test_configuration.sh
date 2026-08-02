#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

bash -n \
    init.sh \
    bash/bash_profile \
    bash/bash_prompt \
    bash/bashrc \
    docker/boot.sh \
    git/git-init.sh \
    test.sh \
    tests/shell/test_bootstrap.sh \
    tests/shell/test_configuration.sh

/bin/sh -n \
    sh/common.sh \
    sh/interactive \
    sh/profile

if ! command -v zsh >/dev/null 2>&1; then
    printf 'zsh is required to validate the supported interactive shell.\n' >&2
    exit 1
fi

zsh -n \
    zsh/zprofile \
    zsh/zsh_prompt \
    zsh/zshrc

git diff --check

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

# Empty executable files are enough for command -v to discover these optional
# tools while the shared configuration is sourced.
for command_name in bat fd nvim rmv; do
    touch "$temporary_binary_directory/$command_name"
    chmod +x "$temporary_binary_directory/$command_name"
done

for shell_executable in /bin/sh "$(command -v bash)" "$(command -v zsh)"; do
    HOME="$temporary_home" \
        PATH="$temporary_binary_directory:/usr/bin:/bin" \
        "$shell_executable" -c '
            . "$1"

            alias vim | grep -q nvim
            alias rm | grep -q rmv

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

# Sourcing the portable profile repeatedly must not duplicate ~/.local/bin.
HOME="$temporary_home" \
    PATH="$temporary_binary_directory:/usr/bin:/bin" \
    /bin/sh -c '
        . "$1"
        . "$1"

        local_binary_count=$(
            printf "%s\n" "$PATH" |
                awk -F : -v expected="$HOME/.local/bin" \
                    '"'"'{ for (field_number = 1; field_number <= NF; field_number++) if ($field_number == expected) count++ } END { print count + 0 }'"'"'
        )
        [ "$local_binary_count" -eq 1 ]
    ' dotfiles-test "$PWD/sh/profile"
