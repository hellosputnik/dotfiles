#!/bin/bash

# Wrapper script to run the dotfiles Docker environment.

# Set the image name.
IMAGE_NAME="altimit"
BUILD_FLAG=0
TARGET_DIRECTORY=""
USERNAME="$(whoami)"

# Parse the command-line arguments.
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_FLAG=1
            shift
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

# Default to the current directory if no target directory is specified.
if [ -z "$TARGET_DIRECTORY" ]; then
    TARGET_DIRECTORY="$(pwd)"
fi

# Ensure that the target directory exists.
if [ ! -d "$TARGET_DIRECTORY" ]; then
    echo "Error: Directory '$TARGET_DIRECTORY' does not exist."
    exit 1
fi

# Resolve the absolute path for the target directory.
TARGET_DIRECTORY="$(cd "$TARGET_DIRECTORY" && pwd)"


echo "Mounting workspace: $TARGET_DIRECTORY"

# Locate the script directory to find the Dockerfile and build context.
# We resolve the symlink to ensure we find the actual directory of the script.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do 
  DIRECTORY="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIRECTORY/$SOURCE" 
done
SCRIPT_DIRECTORY="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
REPOSITORY_ROOT="$(dirname "$SCRIPT_DIRECTORY")"

# Build the image if it does not exist or if the --build flag is provided.
if [[ "$(docker images -q ${IMAGE_NAME} 2> /dev/null)" == "" ]] || [[ ${BUILD_FLAG} -eq 1 ]]; then
    echo "Building Docker image '${IMAGE_NAME}'..."
    echo "Build context: ${REPOSITORY_ROOT}"

    # Build using the repository root as the context so we can COPY all dotfiles.
    # We pass the current user's UID/GID so the container user matches the host user.
    docker build \
        --build-arg UID=$(id -u) \
        --build-arg GID=$(id -g) \
        --build-arg USERNAME="${USERNAME}" \
        -t ${IMAGE_NAME} \
        -f "${SCRIPT_DIRECTORY}/Dockerfile" "${REPOSITORY_ROOT}"
fi

# Run the container.
# -it: Enable an interactive terminal.
# --rm: Remove the container after exit.
# -v $TARGET_DIRECTORY:/workspace: Mount the target directory as the workspace.
# -v $HOME/.ssh:/home/${USERNAME}/.ssh:ro: Mount SSH keys (Read-Only) for Git operations.
# -v $HOME/.gitconfig:/home/${USERNAME}/.gitconfig:ro: Mount the Git identity configuration.
echo "Entering portable environment..."
docker run -it --rm \
    -v "$TARGET_DIRECTORY:/workspace" \
    -v "$HOME/.ssh:/home/${USERNAME}/.ssh:ro" \
    -v "$HOME/.gitconfig:/home/${USERNAME}/.gitconfig:ro" \
    ${IMAGE_NAME}
