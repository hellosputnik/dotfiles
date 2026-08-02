#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

run_test() {
    local description=$1
    shift

    printf '%-32s' "$description"
    if "$@"; then
        printf 'passed\n'
    else
        printf 'failed\n'
        return 1
    fi
}

run_test "Configuration and syntax" tests/shell/test_configuration.sh
run_test "Idempotent bootstrap" tests/shell/test_bootstrap.sh
run_test "Interactive shell behavior" python3 tests/shell/test_interactive_shells.py

if command -v shellcheck >/dev/null 2>&1; then
    run_test "ShellCheck" shellcheck -x -e SC1090 \
        init.sh \
        bash/bash_profile \
        bash/bash_prompt \
        bash/bashrc \
        docker/boot.sh \
        git/git-init.sh \
        tests/shell/test_bootstrap.sh \
        tests/shell/test_configuration.sh \
        test.sh
    run_test "POSIX ShellCheck" shellcheck -x -s sh -e SC1090 \
        sh/common.sh \
        sh/interactive \
        sh/profile
else
    printf '%-32s%s\n' "ShellCheck" "skipped (not installed)"
fi

if command -v shfmt >/dev/null 2>&1; then
    run_test "shfmt" shfmt -d -i 4 -ci \
        init.sh \
        bash/bash_profile \
        bash/bash_prompt \
        bash/bashrc \
        docker/boot.sh \
        git/git-init.sh \
        sh/common.sh \
        sh/interactive \
        sh/profile \
        tests/shell/test_bootstrap.sh \
        tests/shell/test_configuration.sh \
        test.sh
else
    printf '%-32s%s\n' "shfmt" "skipped (not installed)"
fi
