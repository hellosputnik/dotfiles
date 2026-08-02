#!/usr/bin/env python3

import os
import pathlib
import pty
import re
import select
import shutil
import signal
import subprocess
import tempfile
import time
import unittest


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[2]
PROMPT_MARKER = "__DOTFILES_PROMPT_READY__"
STATE_MARKER = "__DOTFILES_STATE__"


def run_command(arguments: list[str], working_directory: pathlib.Path, environment: dict[str, str]) -> None:
    subprocess.run(
        arguments,
        cwd=working_directory,
        env=environment,
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )


def remove_terminal_control_sequences(output: bytes) -> str:
    text = output.decode("utf-8", errors="replace")
    text = re.sub(r"\x1b\][^\x07]*(?:\x07|\x1b\\)", "", text)
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    text = re.sub(r"\x1b[()][0-2A-Z]", "", text)
    text = re.sub(r"\x1b.", "", text)
    text = text.replace("\x01", "").replace("\x02", "")
    return text.replace("\r\n", "\n").replace("\r", "\n")


def read_until_marker_and_quiet(
    terminal_file_descriptor: int,
    marker: str,
    timeout_seconds: float = 15.0,
    quiet_seconds: float = 0.4,
) -> bytes:
    output = bytearray()
    marker_bytes = marker.encode()
    deadline = time.monotonic() + timeout_seconds
    last_output_time = time.monotonic()

    while time.monotonic() < deadline:
        readable, _, _ = select.select([terminal_file_descriptor], [], [], 0.1)
        if readable:
            try:
                chunk = os.read(terminal_file_descriptor, 65536)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
            last_output_time = time.monotonic()
            continue

        if marker_bytes in output and time.monotonic() - last_output_time >= quiet_seconds:
            return bytes(output)

    cleaned_output = remove_terminal_control_sequences(bytes(output))
    raise AssertionError(f"Timed out waiting for {marker!r}. Shell output:\n{cleaned_output}")


def close_interactive_shell(child_process_id: int, terminal_file_descriptor: int) -> None:
    try:
        os.write(terminal_file_descriptor, b"exit\n")
    except OSError:
        pass

    deadline = time.monotonic() + 2.0
    while time.monotonic() < deadline:
        finished_process_id, _ = os.waitpid(child_process_id, os.WNOHANG)
        if finished_process_id == child_process_id:
            break
        time.sleep(0.05)
    else:
        os.kill(child_process_id, signal.SIGTERM)
        os.waitpid(child_process_id, 0)

    os.close(terminal_file_descriptor)


class InteractiveShellTests(unittest.TestCase):
    temporary_directory: tempfile.TemporaryDirectory[str]
    temporary_home: pathlib.Path
    prompt_repository: pathlib.Path
    environment: dict[str, str]

    @classmethod
    def setUpClass(cls) -> None:
        cls.temporary_directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary_directory.cleanup)

        temporary_root = pathlib.Path(cls.temporary_directory.name)
        cls.temporary_home = temporary_root / "home"
        cls.temporary_home.mkdir()
        (cls.temporary_home / ".tmux/plugins/tpm").mkdir(parents=True)

        cls.environment = os.environ.copy()
        cls.environment.update(
            {
                "HOME": str(cls.temporary_home),
                "DOCKER": "true",
                "NO_COLOR": "1",
                "INSTALL_HOMEBREW_BUNDLE": "false",
                "TERM": "xterm-256color",
                "ZDOTDIR": str(cls.temporary_home),
                "BASH_SILENCE_DEPRECATION_WARNING": "1",
            }
        )

        run_command(["./init.sh"], REPOSITORY_ROOT, cls.environment)

        (cls.temporary_home / ".bashrc.local").write_text(
            "export DOTFILES_LOCAL_OVERRIDE_LOADED=bash\n"
            "alias vim='local-bash-vim'\n",
            encoding="utf-8",
        )
        (cls.temporary_home / ".zshrc.local").write_text(
            "export DOTFILES_LOCAL_OVERRIDE_LOADED=zsh\n"
            "alias vim='local-zsh-vim'\n",
            encoding="utf-8",
        )

        cls.prompt_repository = cls.temporary_home / "prompt-repository"
        cls.prompt_repository.mkdir()
        run_command(["git", "init"], cls.prompt_repository, cls.environment)
        run_command(["git", "branch", "-M", "main"], cls.prompt_repository, cls.environment)

        tracked_file = cls.prompt_repository / "tracked.txt"
        tracked_file.write_text("initial\n", encoding="utf-8")
        run_command(["git", "add", "tracked.txt"], cls.prompt_repository, cls.environment)
        run_command(
            [
                "git",
                "-c",
                "user.name=Dotfiles Test",
                "-c",
                "user.email=dotfiles-test@example.invalid",
                "commit",
                "-m",
                "Initial test state",
            ],
            cls.prompt_repository,
            cls.environment,
        )

        tracked_file.write_text("stashed\n", encoding="utf-8")
        run_command(["git", "stash", "push", "-m", "Prompt test stash"], cls.prompt_repository, cls.environment)
        tracked_file.write_text("modified\n", encoding="utf-8")

    def start_interactive_shell(
        self,
        shell_name: str,
        working_directory: pathlib.Path,
    ) -> tuple[int, int]:
        shell_executable = shutil.which(shell_name, path=self.environment["PATH"])
        self.assertIsNotNone(shell_executable, f"{shell_name} is required")

        if shell_name == "bash":
            arguments = [
                shell_executable,
                "--noprofile",
                "--rcfile",
                str(self.temporary_home / ".bashrc"),
                "-i",
            ]
        else:
            arguments = [shell_executable, "--no-globalrcs", "-i"]

        child_process_id, terminal_file_descriptor = pty.fork()
        if child_process_id == 0:
            os.chdir(working_directory)
            os.execve(shell_executable, arguments, self.environment)

        return child_process_id, terminal_file_descriptor

    def run_interactive_command(
        self,
        shell_name: str,
        working_directory: pathlib.Path,
        command: str,
        marker: str,
    ) -> str:
        child_process_id, terminal_file_descriptor = self.start_interactive_shell(
            shell_name,
            working_directory,
        )
        try:
            os.write(terminal_file_descriptor, f"{command}\n".encode())
            output = read_until_marker_and_quiet(terminal_file_descriptor, marker)
        finally:
            close_interactive_shell(child_process_id, terminal_file_descriptor)

        cleaned_output = remove_terminal_control_sequences(output)
        lowered_output = cleaned_output.lower()
        for startup_error in ("command not found", "no such file or directory", "insecure directories"):
            self.assertNotIn(startup_error, lowered_output, cleaned_output)
        return cleaned_output

    def test_bash_and_zsh_prompts_are_equivalent(self) -> None:
        prompt_outputs: dict[str, str] = {}

        for shell_name in ("bash", "zsh"):
            with self.subTest(shell=shell_name):
                output = self.run_interactive_command(
                    shell_name,
                    self.prompt_repository,
                    "printf '__DOTFILES_%s__\\n' PROMPT_READY",
                    PROMPT_MARKER,
                )
                prompt = output.rsplit(PROMPT_MARKER, maxsplit=1)[1]

                self.assertTrue(prompt.startswith("\n\n"), repr(prompt))
                self.assertIn("main  [$!]", prompt)
                self.assertNotIn("[\\$!]", prompt)
                self.assertNotIn("\\n", prompt)
                self.assertNotIn("\\$", prompt)

                prompt_character = "#" if os.geteuid() == 0 else "$"
                self.assertTrue(prompt.endswith(f"\n{prompt_character} "), repr(prompt))
                prompt_outputs[shell_name] = prompt

        self.assertEqual(prompt_outputs["bash"], prompt_outputs["zsh"])

    def test_local_overrides_and_shell_integrations_load(self) -> None:
        bash_output = self.run_interactive_command(
            "bash",
            self.temporary_home,
            (
                "printf '__DOTFILES_%s__%s|%s|%s\\n' STATE "
                '"${DOTFILES_LOCAL_OVERRIDE_LOADED:-missing}" '
                '"$(alias vim)" '
                '"$(type -t _init_completion 2>/dev/null || true)"'
            ),
            STATE_MARKER,
        )
        bash_state = bash_output.rsplit(STATE_MARKER, maxsplit=1)[1].splitlines()[0]
        self.assertIn("bash|alias vim='local-bash-vim'", bash_state)

        homebrew_prefix = os.environ.get("HOMEBREW_PREFIX")
        if homebrew_prefix is None and shutil.which("brew"):
            homebrew_prefix = subprocess.run(
                ["brew", "--prefix"],
                check=True,
                capture_output=True,
                text=True,
                timeout=10,
            ).stdout.strip()

        if homebrew_prefix is not None:
            bash_completion = pathlib.Path(homebrew_prefix) / "etc/profile.d/bash_completion.sh"
            if bash_completion.is_file():
                self.assertTrue(bash_state.endswith("|function"), bash_state)

        zsh_output = self.run_interactive_command(
            "zsh",
            self.temporary_home,
            (
                "printf '__DOTFILES_%s__%s|%s|%s|%s|%s|%s|%s\\n' STATE "
                '"${DOTFILES_LOCAL_OVERRIDE_LOADED:-missing}" '
                '"$(alias vim)" '
                "\"$(bindkey '^[[A')\" "
                '"${+functions[_zsh_autosuggest_start]}" '
                '"${+functions[_zsh_highlight]}" '
                '"${+parameters[_comps]}" '
                '"${fpath[*]}"'
            ),
            STATE_MARKER,
        )
        zsh_state = zsh_output.rsplit(STATE_MARKER, maxsplit=1)[1].splitlines()[0]
        self.assertIn("zsh|vim='local-zsh-vim'", zsh_state)
        self.assertIn("up-line-or-beginning-search", zsh_state)
        self.assertIn("|1|", zsh_state, "compinit did not initialize the _comps parameter")

        if homebrew_prefix is not None:
            homebrew_path = pathlib.Path(homebrew_prefix)
            autosuggestions_script = (
                homebrew_path / "share/zsh-autosuggestions/zsh-autosuggestions.zsh"
            )
            syntax_highlighting_script = (
                homebrew_path / "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
            )
            completions_directory = homebrew_path / "share/zsh-completions"

            state_fields = zsh_state.split("|", maxsplit=6)
            if autosuggestions_script.is_file():
                self.assertEqual(state_fields[3], "1")
            if syntax_highlighting_script.is_file():
                self.assertEqual(state_fields[4], "1")
            if completions_directory.is_dir():
                self.assertIn(str(completions_directory), state_fields[6])


if __name__ == "__main__":
    unittest.main(verbosity=2)
