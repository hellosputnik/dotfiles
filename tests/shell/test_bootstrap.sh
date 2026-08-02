#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

temporary_directory=$(mktemp -d)
cleanup() {
    if [[ -n "${temporary_directory:-}" && -d "$temporary_directory" ]]; then
        rm -rf -- "$temporary_directory"
    fi
}
trap cleanup EXIT

temporary_home="$temporary_directory/home"
bootstrap_output="$temporary_directory/bootstrap.log"
mkdir -p "$temporary_home/.tmux/plugins/tpm"

run_bootstrap() {
    if ! HOME="$temporary_home" \
            DOCKER=true \
            NO_COLOR=1 \
            INSTALL_HOMEBREW_BUNDLE=false \
            ./init.sh >"$bootstrap_output" 2>&1; then
        cat "$bootstrap_output" >&2
        return 1
    fi
}

run_bootstrap

for installed_file in \
    .profile \
    .shellrc \
    .bash_profile \
    .bash_prompt \
    .bashrc \
    .zprofile \
    .zsh_prompt \
    .zshrc \
    .inputrc; do
    if [[ ! -f "$temporary_home/$installed_file" ]]; then
        printf 'Bootstrap did not install %s.\n' "$installed_file" >&2
        exit 1
    fi
done

printf '%s\n' 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=bash' >"$temporary_home/.bashrc.local"
printf '%s\n' 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=zsh' >"$temporary_home/.zshrc.local"
printf '%s\n' 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=profile' >"$temporary_home/.profile.local"

# A second bootstrap verifies that managed files can be refreshed without
# replacing user-owned local overrides.
run_bootstrap

grep -Fqx 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=bash' "$temporary_home/.bashrc.local"
grep -Fqx 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=zsh' "$temporary_home/.zshrc.local"
grep -Fqx 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=profile' "$temporary_home/.profile.local"

cmp -s sh/profile "$temporary_home/.profile"
cmp -s sh/interactive "$temporary_home/.shellrc"
cmp -s bash/bashrc "$temporary_home/.bashrc"
cmp -s zsh/zshrc "$temporary_home/.zshrc"
