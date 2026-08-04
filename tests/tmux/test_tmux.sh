#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

if ! command -v tmux >/dev/null 2>&1; then
    printf 'tmux is not installed; skipping.\n'
    exit 0
fi

# Use a unique isolated socket identifier to avoid affecting active tmux sessions
socket_identifier="dotfiles_tmux_test_$$"
cleanup() {
    tmux -L "$socket_identifier" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Validate configuration syntax using the isolated socket
tmux -L "$socket_identifier" -f tmux/tmux.conf start-server \; source-file tmux/tmux.conf \; kill-server
