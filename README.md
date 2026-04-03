# Dotfiles

Cross-platform dotfiles with a single `./install` entrypoint.

## What it does

- detects whether it is running on macOS or Ubuntu
- requests `sudo` once and keeps the session alive while the install runs
- installs platform prerequisites and packages
- installs macOS agent skills listed in `packages/macos/skills.txt`
- installs Oh My OpenCode during the macOS post-link flow and verifies it with `doctor`
- installs Tailscale on macOS from the official standalone package, adds a `tailscale` CLI launcher, and installs Ubuntu via the upstream install script
- installs the latest Node.js LTS via `fnm` and the latest Go release via `goenv` on macOS
- applies selected macOS defaults during the macOS install flow
- symlinks managed files from `home/` into `$HOME`
- installs Oh My Zsh plus custom plugin repos on macOS, and keeps Ubuntu on a lighter Zsh setup
- prompts for Git name/email and writes them to `~/.gitconfig.local`
- backs up conflicting files into `~/.dotfiles-backups/<timestamp>/`

## Usage

Fresh machine bootstrap:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ovidiup13/dotfiles/main/bootstrap)"
```

Fresh machine bootstrap for the remote macOS profile:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ovidiup13/dotfiles/main/bootstrap)" -- --macos-profile remote
```

The bootstrap script installs the minimum prerequisites needed to clone the repo into `~/.dotfiles`, then hands off to `~/.dotfiles/install`.

## macOS profiles

macOS installs support two profiles:

- `main`, the default profile. This is the full local-machine setup driven by `.macos`, with the standard macOS Brewfile, Mac App Store apps, defaults, and the main-only app installers such as Tailscale, Ollama, and Boring Notch.
- `remote`, the CLI and devtools profile. This is driven by a separate `.macos-remote` installer, keeps the shared base packages, runtimes, shell setup, GitHub SSH key setup, macOS post-link skills sync, and Oh My OpenCode, while skipping the main-only app-style installs and macOS defaults flow.

If you don't pass `--macos-profile`, the installer uses `main` for backward compatibility.

Use a specific profile on macOS with either entrypoint:

```sh
./install --macos-profile remote
./bootstrap --macos-profile remote
```

Profile-aware behavior on macOS:

- full `./install` uses `.macos` for the `main` profile, `.macos-remote` for the `remote` profile, and still uses `.macos` for the post-link stage it triggers afterward
- `./install --skills` accepts `--macos-profile remote|main` and forwards it to `.macos --post-link`
- `./install --macos-defaults` accepts `--macos-profile`, but only `main` is allowed
- `./.macos --post-link` accepts `--macos-profile remote|main`
- `./.macos --defaults` accepts `--macos-profile`, but rejects `remote`

For unattended installs, set `DOTFILES_GIT_NAME` and `DOTFILES_GIT_EMAIL` before running the installer.

To re-run the macOS post-link tasks later, use:

```sh
./install --skills --macos-profile main
```

To re-apply only the macOS defaults later, use:

```sh
./install --macos-defaults --macos-profile main
```

`./install --macos-defaults --macos-profile remote` is rejected because the defaults flow is main-only.

The macOS post-link flow runs the exact skills sync from `packages/macos/skills.txt`, removes unmanaged global skills, and targets `universal opencode` by default. Override agents with `DOTFILES_SKILLS_AGENTS="opencode cursor"` if needed.

The macOS post-link flow also installs Oh My OpenCode with `npx --yes oh-my-opencode install --no-tui`. It defaults to `DOTFILES_OMO_OPENAI=yes` to match the checked-in OpenCode agent config, and you can override provider flags with `DOTFILES_OMO_CLAUDE`, `DOTFILES_OMO_OPENAI`, `DOTFILES_OMO_GEMINI`, `DOTFILES_OMO_COPILOT`, `DOTFILES_OMO_OPENCODE_ZEN`, `DOTFILES_OMO_ZAI_CODING_PLAN`, and `DOTFILES_OMO_OPENCODE_GO`.

If you already cloned the repo, you can still run the local installer directly:

```sh
git clone <your-repo-url> ~/.dotfiles
cd ~/.dotfiles
./install
```

## Layout

- `install` is the main entrypoint
- `.macos` handles the main macOS workstation install and shared macOS maintenance modes
- `.macos-remote` handles the remote macOS CLI/devtools install
- `scripts/install/macos_common.sh` contains shared macOS installer helpers used by both macOS entrypoints
- `scripts/install/macos_defaults.sh` contains macOS `defaults` settings applied by `.macos`
- `scripts/install/oh_my_opencode.sh` installs and verifies Oh My OpenCode during the macOS post-link stage
- `packages/macos/skills.txt` lists exact Skills CLI installs as `<source> <skill>` on macOS
- `.ubuntu` handles Ubuntu prerequisites and apt installs
- `home/` contains the files that get symlinked into `$HOME`
- `scripts/lib/` contains shared installer helpers

## Development Notes

- validate edited shell scripts with `bash -n path/to/script`
- common checks: `bash -n install`, `bash -n bootstrap`, `bash -n .macos`, `bash -n .macos-remote`, `bash -n .ubuntu`, `bash -n scripts/install/macos_common.sh`, `bash -n scripts/install/oh_my_opencode.sh`, `bash -n scripts/install/skills.sh`
- rerun the macOS post-link flow with `./install --skills --macos-profile main` or `./install --skills --macos-profile remote`
- rerun only the macOS defaults flow with `./install --macos-defaults --macos-profile main`
- smoke test the operator-facing macOS flow with `./install --macos-profile remote` and `./install --macos-profile main`
- smoke test the Ubuntu path with `./.ubuntu`
- keep `packages/macos/skills.txt` entries to one exact `<source> <skill>` mapping per line
- prefer small, idempotent shell changes that preserve the existing `log_step`/`log_info`/`log_warn`/`log_error`/`log_success` output style

## Validation matrix

Shell syntax checks:

```sh
bash -n install
bash -n bootstrap
bash -n .macos
bash -n scripts/install/skills.sh
bash -n scripts/install/oh_my_opencode.sh
```

Focused smoke tests for the operator-facing macOS profile parser and guards:

```sh
python3 - <<'PY'
import os, tempfile, subprocess, pathlib

repo = pathlib.Path.cwd()

def write_exec(path, content):
    path.write_text(content)
    path.chmod(0o755)

def run_case(name, argv, brew_exit_target=None, extra_stubs=None, setup=None):
    case_dir = pathlib.Path(tempfile.mkdtemp(prefix=f"dotfiles-{name}-"))
    stub_dir = case_dir / "stubs"
    home_dir = case_dir / "home"
    stub_dir.mkdir()
    home_dir.mkdir()

    write_exec(stub_dir / "uname", '#!/bin/sh\nprintf "Darwin\\n"\n')
    write_exec(stub_dir / "xcode-select", '#!/bin/sh\nif [ "$1" = "-p" ]; then printf "/Library/Developer/CommandLineTools\\n"; exit 0; fi\nexit 0\n')

    brew_script = '#!/bin/sh\nif [ "$1" = "shellenv" ]; then exit 0; fi\n'
    if brew_exit_target:
        brew_script += f'if [ "$1" = "bundle" ] && [ "$3" = "{brew_exit_target}" ]; then exit 99; fi\n'
    brew_script += 'exit 0\n'
    write_exec(stub_dir / "brew", brew_script)

    if extra_stubs:
      extra_stubs(stub_dir)

    if setup:
      setup(home_dir)

    env = {
        "HOME": str(home_dir),
        "PATH": f"{stub_dir}:/usr/bin:/bin:/usr/sbin:/sbin",
        "DOTFILES_SUDO_ACTIVE": "1",
    }
    return subprocess.run(argv, cwd=repo, env=env, text=True, capture_output=True)

main_result = run_case(
    "main",
    ["./install", "--macos-profile", "main"],
    brew_exit_target=f"{repo}/packages/macos/Brewfile",
)
print(main_result.stdout + main_result.stderr, end="")
assert main_result.returncode == 99

remote_result = run_case(
    "remote",
    ["./install", "--macos-profile", "remote"],
    brew_exit_target=f"{repo}/packages/macos/Brewfile.remote",
)
print(remote_result.stdout + remote_result.stderr, end="")
assert remote_result.returncode == 99

def post_link_stubs(stub_dir):
    write_exec(stub_dir / "skills", '#!/bin/sh\nif [ "$1" = "list" ]; then printf "[]\\n"; exit 0; fi\nexit 0\n')
    write_exec(stub_dir / "opencode", '#!/bin/sh\nexit 0\n')
    write_exec(stub_dir / "npx", '#!/bin/sh\nexit 0\n')

def post_link_setup(home_dir):
    config_dir = home_dir / ".config" / "opencode"
    config_dir.mkdir(parents=True)
    (config_dir / "opencode.json").write_text("{}\n")

post_link_result = run_case(
    "post-link",
    ["./install", "--skills", "--macos-profile", "remote"],
    extra_stubs=post_link_stubs,
    setup=post_link_setup,
)
print(post_link_result.stdout + post_link_result.stderr, end="")
assert post_link_result.returncode == 0
PY

./install --macos-profile invalid
./install --macos-defaults --macos-profile remote
```

The successful smoke cases use temporary PATH stubs and a temporary HOME so they stop at the profile dispatch points without touching the real machine state, while proving the `./install` entrypoint rather than direct `.macos` execution.

## Notes

- macOS App Store installs run only when `mas` is signed in
- rerunning `./install` is safe
- `yadm` is no longer part of the install flow
