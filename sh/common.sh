# POSIX shell helpers used by the installer.
#
# Keep this file compatible with /bin/sh. The installer currently runs under
# Bash, but these helpers do not need Bash-specific syntax.

# Print an aligned log message with a highlighted action prefix.
# Usage: log_action <action> <message>
log_action() (
    action=$1
    message=$2

    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[1;32m%12s\033[0m %s\n' "$action" "$message"
    else
        printf '%12s %s\n' "$action" "$message"
    fi
)

# Get high-resolution epoch time in milliseconds.
get_time_ms() {
    if command -v perl >/dev/null 2>&1; then
        perl -MTime::HiRes=time -e 'print int(time * 1000)'
    else
        printf '%s000\n' "$(date +%s)"
    fi
}

# Format a duration in milliseconds for the log output.
format_duration() (
    duration=$1

    if [ "$duration" -lt 1000 ]; then
        printf '%sms' "$duration"
    else
        seconds=$((duration / 1000))
        centiseconds=$(((duration % 1000) / 10))
        printf '%d.%02ds' "$seconds" "$centiseconds"
    fi
)

# Run a synchronous task, timing it and outputting the duration.
# Usage: run_task <action> <message> <command...>
run_task() (
    action=$1
    message=$2
    shift 2

    start_time=$(get_time_ms)

    # Put the command in an if condition so this helper behaves predictably
    # even when the caller has enabled `set -e`.
    if "$@"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end_time=$(get_time_ms)
    duration=$((end_time - start_time))
    duration_string=$(format_duration "$duration")

    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[1;32m%12s\033[0m %s \033[2min %s\033[0m\n' \
            "$action" "$message" "$duration_string"
    else
        printf '%12s %s in %s\n' "$action" "$message" "$duration_string"
    fi

    return "$exit_code"
)

# Return one Braille spinner character for a zero-based position.
spinner_char() {
    case $1 in
        0) printf '⠋' ;;
        1) printf '⠙' ;;
        2) printf '⠹' ;;
        3) printf '⠸' ;;
        4) printf '⠼' ;;
        5) printf '⠴' ;;
        6) printf '⠦' ;;
        7) printf '⠧' ;;
        8) printf '⠇' ;;
        9) printf '⠏' ;;
        *) printf ' ' ;;
    esac
}

# Run a command in the background with a spinner.
# Usage: run_with_spinner <active_action> <done_action> <message> <command...>
run_with_spinner() (
    active_action=$1
    done_action=$2
    message=$3
    shift 3

    start_time=$(get_time_ms)

    # Run the command in the background and redirect output to a temporary file.
    temporary_output=$(mktemp) || exit 1
    "$@" >"$temporary_output" 2>&1 &
    process_id=$!

    # If standard output is a TTY, animate the spinner. Otherwise, wait silently.
    spinner_index=0
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        while kill -0 "$process_id" 2>/dev/null; do
            spinner_character=$(spinner_char "$spinner_index")
            spinner_index=$(((spinner_index + 1) % 10))
            printf '\r\033[1;32m%12s\033[0m \033[1;36m%s\033[0m %s' \
                "$active_action" "$spinner_character" "$message"
            sleep 0.1
        done
    else
        while kill -0 "$process_id" 2>/dev/null; do
            sleep 0.1
        done
    fi

    if wait "$process_id"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end_time=$(get_time_ms)
    duration=$((end_time - start_time))
    duration_string=$(format_duration "$duration")

    # Clear the spinner line and print the completed log.
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\r\033[K\033[1;32m%12s\033[0m %s \033[2min %s\033[0m\n' \
            "$done_action" "$message" "$duration_string"
    else
        printf '%12s %s in %s\n' "$done_action" "$message" "$duration_string"
    fi

    if [ "$exit_code" -ne 0 ]; then
        if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
            printf '\033[1;31mError:\033[0m Command failed with exit code %d. Output:\n' \
                "$exit_code"
        else
            printf 'Error: Command failed with exit code %d. Output:\n' "$exit_code"
        fi
        cat "$temporary_output"
    fi
    rm -f "$temporary_output"

    return "$exit_code"
)

# Copy a file or directory. For directories, this copies their contents recursively.
# Usage: safe_copy <source> <destination>
safe_copy() (
    source=$1
    destination=$2

    if [ ! -e "$source" ]; then
        printf 'safe_copy: source does not exist: %s\n' "$source" >&2
        return 1
    fi

    if [ -d "$source" ] && [ -e "$destination" ] && [ ! -d "$destination" ]; then
        printf 'safe_copy: destination exists as a file but source is a directory; remove %s manually\n' \
            "$destination" >&2
        return 1
    fi

    if [ ! -d "$source" ] && [ -d "$destination" ]; then
        printf 'safe_copy: destination exists as a directory but source is a file; remove %s manually\n' \
            "$destination" >&2
        return 1
    fi

    mkdir -p "$(dirname "$destination")" || return 1

    if [ -d "$source" ]; then
        mkdir -p "$destination" || return 1
        if command -v rsync >/dev/null 2>&1; then
            # -a: Enable archive mode (preserves timestamps and recursion).
            # --no-perms: Do not strictly enforce permissions across users/filesystems.
            rsync -a --no-perms "${source%/}/" "${destination%/}/"
        else
            # -R: Enable recursive copying.
            # -f: Force the copy.
            cp -Rf "${source%/}/." "${destination%/}/"
        fi
    else
        if command -v rsync >/dev/null 2>&1; then
            rsync -a --no-perms "$source" "$destination"
        else
            cp -f "$source" "$destination"
        fi
    fi
)
