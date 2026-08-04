#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# 1. Validate Homebrew Brewfile Ruby syntax
if command -v ruby >/dev/null 2>&1; then
    ruby -c homebrew/Brewfile >/dev/null
fi

# 2. Verify all entries adhere to standard Brewfile DSL directives
if grep -Ev '^\s*(#|$|(brew|cask|tap|vscode|mas)\s+"[^"]+")' homebrew/Brewfile; then
    printf 'homebrew/Brewfile contains unrecognized directive lines.\n' >&2
    exit 1
fi
