#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# 1. Validate docker/boot.sh shell syntax
bash -n docker/boot.sh

# 2. Check docker/dnf-packages.txt for trailing whitespace on any line
if grep -E '[[:blank:]]+$' docker/dnf-packages.txt; then
    printf 'docker/dnf-packages.txt contains lines with trailing whitespace.\n' >&2
    exit 1
fi

# 3. Verify each non-empty line in docker/dnf-packages.txt is a valid package name or comment
if grep -Ev '^\s*(#|$|[a-zA-Z0-9_@.-]+)' docker/dnf-packages.txt; then
    printf 'docker/dnf-packages.txt contains invalid package entries.\n' >&2
    exit 1
fi

# 4. Validate presence of core instructions in Dockerfile
if [[ -f docker/Dockerfile ]]; then
    grep -q '^FROM ' docker/Dockerfile
    grep -q '^WORKDIR ' docker/Dockerfile
    grep -q '^CMD ' docker/Dockerfile
fi
