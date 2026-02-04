FROM fedora:41

# Copy the list of DNF packages.
COPY docker/dnf-packages.txt /tmp/dnf-packages.txt

# Install packages from the list.
# We also install the 'Development Tools' group for standard build utilities.
RUN dnf update -y && \
    dnf install -y @development-tools && \
    dnf install -y $(cat /tmp/dnf-packages.txt) && \
    dnf clean all && \
    rm /tmp/dnf-packages.txt

# Set the default editor and generate the locale to fix UTF-8 issues for CLI tools.
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV EDITOR=nvim

# Set an environment variable to indicate that we are running inside a Docker container.
ENV DOCKER=true

# Create a non-root user that matches the host user's UID/GID.
# This ensures that files created in the container are owned by you on the host.
ARG UID=1000
ARG GID=1000
ARG USERNAME=neo

# Create the group if it does not exist (handling cases where the GID is already taken by a system group).
RUN if ! getent group ${GID} > /dev/null; then \
        groupadd --gid ${GID} ${USERNAME}; \
    fi

# Create the user and grant passwordless sudo access.
RUN useradd --uid ${UID} --gid ${GID} -m ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Set up the workspace directory.
WORKDIR /workspace

# Switch to the user to install user-level tools.
USER ${USERNAME}

# Copy the repository's dotfiles into the image.
# We copy them to a temporary spot, then install them using the init script.
COPY --chown=${USERNAME}:${USERNAME} . /tmp/dotfiles

# Run the init script to link everything up, then clean up the source files.
RUN cd /tmp/dotfiles && \
    ./init.sh && \
    rm -rf /tmp/dotfiles

# Set the default command to bash.
CMD ["bash"]

