# sh/common.sh
# Shared installation and console utilities for dotfiles setup.

# Print an aligned log message with a highlighted action prefix.
# Usage: log_action <action> <message>
log_action() {
    local action="$1"
    local message="$2"
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf "\033[1;32m%12s\033[0m %s\n" "$action" "$message"
    else
        printf "%12s %s\n" "$action" "$message"
    fi
}

# Get high-resolution epoch time in milliseconds.
get_time_ms() {
    if command -v perl >/dev/null 2>&1; then
        perl -MTime::HiRes=time -e 'print int(time * 1000)'
    else
        echo "$(date +%s)000"
    fi
}

# Run a synchronous task, timing it and outputting the duration.
# Usage: run_task <action> <message> <command...>
run_task() {
    local action="$1"
    local message="$2"
    shift 2

    local start_time
    start_time=$(get_time_ms)

    "$@"

    local end_time
    end_time=$(get_time_ms)
    local duration=$((end_time - start_time))

    local duration_str=""
    if [ $duration -lt 1000 ]; then
        duration_str="${duration}ms"
    else
        local secs=$((duration / 1000))
        local ms=$(( (duration % 1000) / 10 ))
        duration_str=$(printf "%d.%02ds" "$secs" "$ms")
    fi

    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf "\033[1;32m%12s\033[0m %s \033[2min %s\033[0m\n" "$action" "$message" "$duration_str"
    else
        printf "%12s %s in %s\n" "$action" "$message" "$duration_str"
    fi
}

# Run a command in the background with a spinner.
# Usage: run_with_spinner <active_action> <done_action> <message> <command...>
run_with_spinner() {
    local active_action="$1"
    local done_action="$2"
    local message="$3"
    shift 3

    local start_time
    start_time=$(get_time_ms)

    # Run command in background and redirect output to temp file
    local temp_out
    temp_out=$(mktemp)
    
    "$@" > "$temp_out" 2>&1 &
    local pid=$!

    # Braille spinner characters
    local spin="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0

    # If stdout is a TTY, animate the spinner. Otherwise, wait silently.
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        while kill -0 "$pid" 2>/dev/null; do
            local char="${spin:$i:1}"
            i=$(( (i + 1) % 10 ))
            printf "\r\033[1;32m%12s\033[0m \033[1;36m%s\033[0m %s" "$active_action" "$char" "$message"
            sleep 0.1
        done
    else
        while kill -0 "$pid" 2>/dev/null; do
            sleep 0.1
        done
    fi

    wait "$pid"
    local exit_code=$?

    local end_time
    end_time=$(get_time_ms)
    local duration=$((end_time - start_time))

    local duration_str=""
    if [ $duration -lt 1000 ]; then
        duration_str="${duration}ms"
    else
        local secs=$((duration / 1000))
        local ms=$(( (duration % 1000) / 10 ))
        duration_str=$(printf "%d.%02ds" "$secs" "$ms")
    fi

    # Clear spinner line and print completed log
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf "\r\033[K\033[1;32m%12s\033[0m %s \033[2min %s\033[0m\n" "$done_action" "$message" "$duration_str"
    else
        printf "%12s %s in %s\n" "$done_action" "$message" "$duration_str"
    fi

    if [ $exit_code -ne 0 ]; then
        printf "\033[1;31mError:\033[0m Command failed with exit code %d. Output:\n" "$exit_code"
        cat "$temp_out"
    fi
    rm -f "$temp_out"

    return $exit_code
}

# Copy a file or directory; for directories, copies *contents* into destination.
# Usage: safe_copy <source> <destination>
safe_copy() {
    local source="$1"
    local destination="$2"

    if [ ! -e "$source" ]; then
        echo "safe_copy: source does not exist: $source" >&2
        return 1
    fi

    if [ -d "$source" ] && [ -e "$destination" ] && [ ! -d "$destination" ]; then
        echo "safe_copy: destination exists as a file but source is a directory; remove $destination manually" >&2
        return 1
    fi

    if [ ! -d "$source" ] && [ -d "$destination" ]; then
        echo "safe_copy: destination exists as a directory but source is a file; remove $destination manually" >&2
        return 1
    fi

    mkdir -p "$(dirname "$destination")"

    if [ -d "$source" ]; then
        mkdir -p "$destination"
        if command -v rsync > /dev/null; then
            # -a: Enable archive mode (preserves timestamps and recursion).
            # --no-perms: Do not strictly enforce permissions (useful when syncing across filesystems or users).
            rsync -a --no-perms "${source%/}/" "${destination%/}/"
        else
            # Fallback to the standard cp command.
            # -R: Enable recursive copy.
            # -f: Force the copy.
            cp -Rf "${source%/}/." "${destination%/}/"
        fi
    else
        if command -v rsync > /dev/null; then
            rsync -a --no-perms "$source" "$destination"
        else
            cp -f "$source" "$destination"
        fi
    fi
}
