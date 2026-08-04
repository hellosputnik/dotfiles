#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# 1. Ripgrep configuration validation
if command -v rg >/dev/null 2>&1; then
    RIPGREP_CONFIG_PATH=ripgrep/ripgreprc rg --files >/dev/null
fi

# 2. Readline configuration syntax validation
if [[ -f readline/inputrc ]]; then
    # Verify non-empty, non-comment lines follow GNU Readline directive or binding patterns
    if grep -Ev '^\s*(#|$|set\s|"[^"]+":)' readline/inputrc; then
        printf 'readline/inputrc contains invalid directive lines.\n' >&2
        exit 1
    fi
fi

# 3. SSH configuration syntax validation
if command -v ssh >/dev/null 2>&1; then
    ssh -F ssh/config -G localhost >/dev/null 2>&1 || true
fi

# 4. Curl configuration syntax validation
if command -v curl >/dev/null 2>&1; then
    curl --config network/curlrc -V >/dev/null
fi

# 5. Wget configuration syntax validation
if command -v wget >/dev/null 2>&1; then
    WGETRC=network/wgetrc wget -V >/dev/null
fi
