.PHONY: all install check test

all: install

install:
	@./init.sh

check:
	@bash -n init.sh bash/bash_profile bash/bash_prompt bash/bashrc docker/boot.sh git/git-init.sh
	@/bin/sh -n sh/common.sh sh/interactive sh/profile
	@if command -v zsh >/dev/null 2>&1; then zsh -n zsh/zprofile zsh/zsh_prompt zsh/zshrc; fi
	@echo "All configuration files passed syntax check."

test:
	@./test.sh
