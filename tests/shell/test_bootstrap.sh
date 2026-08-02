#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# 1. Create an isolated sandbox directory for testing ./init.sh bootstrap
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

# Helper function to run ./init.sh in non-interactive sandbox mode
run_bootstrap() {
    if ! HOME="$temporary_home" \
        DOCKER=true \
        NO_COLOR=1 \
        INSTALL_HOMEBREW_BUNDLE=false \
        ./init.sh </dev/null >"$bootstrap_output" 2>&1; then
        cat "$bootstrap_output" >&2
        return 1
    fi
}

# 2. Run initial bootstrap
run_bootstrap

# 3. Verify all expected configuration files were deployed into $HOME
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

# 4. Create custom user local override files in $HOME
printf '%s\n' 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=bash' >"$temporary_home/.bashrc.local"
printf '%s\n' 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=zsh' >"$temporary_home/.zshrc.local"
printf '%s\n' 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=profile' >"$temporary_home/.profile.local"

# 5. Run a second bootstrap to verify idempotency (preserves user local files)
run_bootstrap

# 6. Assert user local files were preserved without being overwritten
grep -Fqx 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=bash' "$temporary_home/.bashrc.local"
grep -Fqx 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=zsh' "$temporary_home/.zshrc.local"
grep -Fqx 'export DOTFILES_LOCAL_OVERRIDE_PRESERVED=profile' "$temporary_home/.profile.local"

# 7. Compare installed files against repository source files to ensure exact match
cmp -s sh/profile "$temporary_home/.profile"
cmp -s sh/interactive "$temporary_home/.shellrc"
cmp -s bash/bashrc "$temporary_home/.bashrc"
cmp -s zsh/zshrc "$temporary_home/.zshrc"
