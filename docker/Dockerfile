FROM fedora:41

COPY docker/dnf-packages.txt /tmp/dnf-packages.txt

# Leverage BuildKit cache mounts for DNF to speed up rebuilding
RUN --mount=type=cache,target=/var/cache/dnf \
    dnf update -y && \
    dnf install -y @development-tools && \
    xargs dnf install -y < /tmp/dnf-packages.txt && \
    dnf clean all && \
    rm /tmp/dnf-packages.txt

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV EDITOR=nvim
ENV DOCKER=true

ARG UID=1000
ARG GID=1000
ARG USERNAME=neo

# Create group if not already present on host to handle GID collisions
RUN if ! getent group ${GID} > /dev/null; then \
    groupadd --gid ${GID} ${USERNAME}; \
    fi

RUN useradd --uid ${UID} --gid ${GID} -m ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

WORKDIR /tmp/dotfiles

COPY --chown=${USERNAME}:${USERNAME} . .

RUN ./init.sh

WORKDIR /workspace

CMD ["bash"]
