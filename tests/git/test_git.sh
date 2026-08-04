#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# 1. Validate main gitconfig syntax
git config --file git/gitconfig --list >/dev/null

# 2. Test git/git-init.sh non-interactively inside a sandbox environment
temporary_directory=$(mktemp -d)
cleanup() {
    if [[ -n "${temporary_directory:-}" && -d "$temporary_directory" ]]; then
        rm -rf -- "$temporary_directory"
    fi
}
trap cleanup EXIT

temporary_home="$temporary_directory/home"
mkdir -p "$temporary_home"

printf "Test User\ntest@example.com\nnvim\n" | HOME="$temporary_home" sh git/git-init.sh >/dev/null

# 3. Assert user local config options were properly populated
git config --file "$temporary_home/.gitconfig.local" user.name | grep -q "Test User"
git config --file "$temporary_home/.gitconfig.local" user.email | grep -q "test@example.com"
git config --file "$temporary_home/.gitconfig.local" core.editor | grep -q "nvim"

# 4. Check gitignore entries
if [[ -f git/gitignore ]]; then
    git config --file git/gitconfig core.excludesFile | grep -q '\.gitignore'
fi
