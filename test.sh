#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# Color definitions (respect NO_COLOR and non-interactive TTYs)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD="\033[1m"
    RESET="\033[0m"
    GREEN="\033[1;32m"
    RED="\033[1;31m"
    YELLOW="\033[1;33m"
    BLUE="\033[1;34m"
    DIM="\033[2m"
else
    BOLD=""
    RESET=""
    GREEN=""
    RED=""
    YELLOW=""
    BLUE=""
    DIM=""
fi

format_duration() {
    local ms=$1
    if [ "$ms" -lt 1000 ]; then
        printf "%dms" "$ms"
    else
        local secs=$((ms / 1000))
        local tenths=$(((ms % 1000) / 100))
        printf "%d.%ds" "$secs" "$tenths"
    fi
}

get_time_ms() {
    python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s000
}

run_test() {
    local description=$1
    shift

    local start_time end_time duration duration_str
    start_time=$(get_time_ms)

    local output_file
    output_file=$(mktemp)

    local dots=".................................................."
    local label_len=${#description}
    local pad_len=$((40 - label_len))
    if [ $pad_len -lt 2 ]; then pad_len=2; fi
    local padding="${dots:0:$pad_len}"

    printf "  ${BOLD}%s${RESET} ${DIM}%s${RESET} " "$description" "$padding"

    if "$@" >"$output_file" 2>&1; then
        end_time=$(get_time_ms)
        duration=$((end_time - start_time))
        duration_str=$(format_duration "$duration")
        printf "${GREEN}✓ PASS${RESET} ${DIM}(%s)${RESET}\n" "$duration_str"
        rm -f "$output_file"
    else
        end_time=$(get_time_ms)
        duration=$((end_time - start_time))
        duration_str=$(format_duration "$duration")
        printf "${RED}✗ FAIL${RESET} ${DIM}(%s)${RESET}\n" "$duration_str"
        printf "%b\n" "\n${RED}--- Failure Output: ${description} ---${RESET}"
        cat "$output_file"
        printf "%b\n" "${RED}------------------------------------------${RESET}"
        printf "\n"
        rm -f "$output_file"
        return 1
    fi
}

run_skip() {
    local description=$1
    local reason=$2
    local dots=".................................................."
    local pad_len=$((40 - ${#description}))
    if [ $pad_len -lt 2 ]; then pad_len=2; fi
    local padding="${dots:0:$pad_len}"
    printf "  ${BOLD}%s${RESET} ${DIM}%s${RESET} ${YELLOW}- SKIP${RESET} ${DIM}(%s)${RESET}\n" "$description" "$padding" "$reason"
}

printf "\n${BOLD}${BLUE}Dotfiles Test Suite${RESET}\n\n"

# 1. Static Analysis (Fast fail check)
if command -v shellcheck >/dev/null 2>&1; then
    run_test "ShellCheck (Bash)" shellcheck -x -s bash -e SC1090,SC1091,SC2088,SC2148,SC2059,SC2016 \
        init.sh \
        bash/bash_profile \
        bash/bash_prompt \
        bash/bashrc \
        docker/boot.sh \
        git/git-init.sh \
        tests/docker/test_docker.sh \
        tests/editors/test_editors.sh \
        tests/git/test_git.sh \
        tests/homebrew/test_brewfile.sh \
        tests/shell/test_bootstrap.sh \
        tests/shell/test_configuration.sh \
        tests/tmux/test_tmux.sh \
        tests/tools/test_tools.sh \
        test.sh
    run_test "ShellCheck (POSIX sh)" shellcheck -x -s sh -e SC1090,SC1091,SC2088,SC2089,SC2090,SC2148,SC2059 \
        sh/common.sh \
        sh/interactive \
        sh/profile
else
    run_skip "ShellCheck" "not installed"
fi

# 2. Core Shell & Bootstrap
run_test "Configuration and syntax" tests/shell/test_configuration.sh
run_test "Idempotent bootstrap" tests/shell/test_bootstrap.sh

# 3. Environment & Package Management
run_test "Homebrew Brewfile" tests/homebrew/test_brewfile.sh

# 4. CLI Tools & Core Utilities
run_test "CLI and network tools" tests/tools/test_tools.sh
run_test "Git configuration and bootstrap" tests/git/test_git.sh
run_test "Isolated tmux configuration" tests/tmux/test_tmux.sh

# 5. Text Editors
run_test "Vim and Neovim editors" tests/editors/test_editors.sh

# 6. Container Integration
run_test "Docker environment" tests/docker/test_docker.sh

printf "\n"
