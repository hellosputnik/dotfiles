#!/bin/bash

# Wrapper script to run the dotfiles Docker environment.

# Set the Docker image name.
IMAGE_NAME="altimit"
BUILD_FLAG=0
CLEAN_FLAG=0
TARGET_DIRECTORY=""
SHELL_COMMAND="bash"
USERNAME="$(whoami)"

show_help() {
    echo "Usage: boot [options] [target_directory]"
    echo ""
    echo "Options:"
    echo "  --build      Force a rebuild of the Docker image."
    echo "  --clean      Run in a clean, isolated environment (do not mount host *.local files)."
    echo "  --shell NAME Start Bash or zsh inside the container (default: bash)."
    echo "  -h, --help   Show this help message."
    exit 0
}

# Parse the command-line arguments.
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_FLAG=1
            shift
            ;;
        --clean)
            CLEAN_FLAG=1
            shift
            ;;
        --shell)
            shift
            if [ $# -eq 0 ]; then
                echo "Error: --shell requires bash or zsh."
                exit 1
            fi
            SHELL_COMMAND="$1"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            if [ -z "$TARGET_DIRECTORY" ]; then
                TARGET_DIRECTORY="$1"
            else
                echo "Unknown argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

case "$SHELL_COMMAND" in
    bash|zsh)
        ;;
    *)
        echo "Error: unsupported shell '$SHELL_COMMAND'. Choose bash or zsh."
        exit 1
        ;;
esac

# Default to the current directory if no target directory is specified.
if [ -z "$TARGET_DIRECTORY" ]; then
    TARGET_DIRECTORY="$(pwd)"
fi

# Ensure the target directory exists.
if [ ! -d "$TARGET_DIRECTORY" ]; then
    echo "Error: Directory '$TARGET_DIRECTORY' does not exist."
    exit 1
fi

# Resolve the absolute path of the target directory.
TARGET_DIRECTORY="$(cd "$TARGET_DIRECTORY" && pwd)"


echo "Mounting workspace: $TARGET_DIRECTORY"

# Locate the script directory to find the Dockerfile and build context.
# Resolve symlinks to ensure the actual script directory is resolved.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do 
  DIRECTORY="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIRECTORY/$SOURCE" 
done
SCRIPT_DIRECTORY="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
REPOSITORY_ROOT="$(dirname "$SCRIPT_DIRECTORY")"

# Build the image if it does not exist or if the --build flag is set.
if [[ "$(docker images -q ${IMAGE_NAME} 2> /dev/null)" == "" ]] || [[ ${BUILD_FLAG} -eq 1 ]]; then
    echo "Building Docker image '${IMAGE_NAME}'..."
    echo "Build context: ${REPOSITORY_ROOT}"

    # Build using the repository root as context to copy all dotfiles.
    # Pass the current user's UID and GID so the container user matches the host user.
    docker build \
        --build-arg "UID=$(id -u)" \
        --build-arg "GID=$(id -g)" \
        --build-arg USERNAME="${USERNAME}" \
        -t ${IMAGE_NAME} \
        -f "${SCRIPT_DIRECTORY}/Dockerfile" "${REPOSITORY_ROOT}"
fi

# Run the container.
# -it: Enable an interactive terminal.
# --rm: Remove the container after exit.
# -v $TARGET_DIRECTORY:/workspace: Mount the target directory as the workspace.
# -v $HOME/.ssh:/home/${USERNAME}/.ssh:ro: Mount SSH keys (read-only) for Git operations.
# -v $HOME/.gitconfig:/home/${USERNAME}/.gitconfig:ro: Mount the Git identity configuration.
MOUNT_ARGS=(
    -v "$TARGET_DIRECTORY:/workspace"
    -v "$HOME/.ssh:/home/${USERNAME}/.ssh:ro"
    -v "$HOME/.gitconfig:/home/${USERNAME}/.gitconfig:ro"
)

# Mount local overrides (Git identity and shell overrides) if not running in a clean environment.
if [[ ${CLEAN_FLAG} -eq 0 ]]; then
    if [ -f "$HOME/.gitconfig.local" ]; then
        MOUNT_ARGS+=( -v "$HOME/.gitconfig.local:/home/${USERNAME}/.gitconfig.local:ro" )
    fi
    if [ -f "$HOME/.bashrc.local" ]; then
        MOUNT_ARGS+=( -v "$HOME/.bashrc.local:/home/${USERNAME}/.bashrc.local:ro" )
    fi
    if [ -f "$HOME/.zshrc.local" ]; then
        MOUNT_ARGS+=( -v "$HOME/.zshrc.local:/home/${USERNAME}/.zshrc.local:ro" )
    fi
fi

echo "Entering portable environment with ${SHELL_COMMAND}..."
docker run -it --rm "${MOUNT_ARGS[@]}" "$IMAGE_NAME" "$SHELL_COMMAND" -i
