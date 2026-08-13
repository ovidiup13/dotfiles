# Dotfiles

Cross-platform dotfiles with a single `./install` entrypoint.

## What it does

- detects whether it is running on macOS or Ubuntu
- requests `sudo` once and keeps the session alive while the install runs
- installs platform prerequisites and packages
- links vendored agent skills from `home/.agents/skills`
- installs Tailscale on macOS from the official standalone package, adds a `tailscale` CLI launcher, and installs Ubuntu via the upstream install script
- installs `uv` from Astral and Rust via the official `rustup` installer on all platforms
- installs Basic Memory with `uv` on all platforms and configures its local OpenCode MCP server
- installs Vite+ `vp` with Node.js management enabled and the latest Go release via `goenv` on macOS
- installs monitoring tools on demand with `./install --monitoring`, including the Beszel agent via Homebrew
- applies selected macOS defaults during the macOS install flow
- symlinks managed files from `home/` into `$HOME`
- installs Oh My Zsh plus custom plugin repos on macOS, and keeps Ubuntu on a lighter Zsh setup
- prompts for Git name/email and writes them to `~/.gitconfig.local`
- syncs 1Password Environment variables into a local `~/.secrets/tokens` file on demand
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
- `remote`, the CLI and devtools profile. This uses `.macos --macos-profile remote`, keeps the shared base packages, runtimes, shell setup, and GitHub SSH key setup, while skipping the main-only app-style installs and macOS defaults flow.

If you don't pass `--macos-profile`, the installer uses `main` for backward compatibility.

Use a specific profile on macOS with either entrypoint:

```sh
./install --macos-profile remote
./bootstrap --macos-profile remote
```

Profile-aware behavior on macOS:

- full `./install` uses `.macos` for both `main` and `remote` profiles
- `./install --skills` relinks the vendored `home/.agents/skills` subtree
- `./install --macos-defaults` accepts `--macos-profile`, but only `main` is allowed
- `./.macos --defaults` accepts `--macos-profile`, but rejects `remote`

For unattended installs, set `DOTFILES_GIT_NAME` and `DOTFILES_GIT_EMAIL` before running the installer.

To relink vendored agent skills later, use:

```sh
./install --skills
```

To re-apply only the macOS defaults later, use:

```sh
./install --macos-defaults --macos-profile main
```

`./install --macos-defaults --macos-profile remote` is rejected because the defaults flow is main-only.

## Secrets

Secrets are managed outside the repository with 1Password Environments. The checked-in shell environment file sources `~/.secrets/tokens` when it exists, but that file is generated locally and must not be committed.

On the first `./install` or `./install --secrets` run, if `~/.secrets/tokens` does not exist and you did not pass an Environment ID, the installer prompts for the 1Password Environment ID interactively. After a successful sync it writes that ID into `~/.secrets/tokens` as `DOTFILES_1PASSWORD_ENVIRONMENT=...`, so later installs can reuse it automatically.

You can still provide the Environment ID explicitly with either an environment variable:

```sh
DOTFILES_1PASSWORD_ENVIRONMENT=<environment-id> ./install --secrets
```

or an explicit flag:

```sh
./install --secrets --1password-environment <environment-id>
```

The secrets sync requires the `op` CLI to be installed and authenticated. It writes `DOTFILES_1PASSWORD_ENVIRONMENT=<environment-id>` plus all variables returned by `op environment read <environment-id>` to `~/.secrets/tokens`, sets `~/.secrets` to mode `700`, and sets the generated file to mode `600`. The generated file is plaintext on disk and is sourced by new shells, so exported secrets are available to child processes in those shells.

Full `./install` now runs the secrets sync automatically after package setup and dotfile linking. The prompt only appears if `DOTFILES_1PASSWORD_ENVIRONMENT` is missing from the generated secrets file and you did not provide it explicitly.

## Monitoring

Run the monitoring-only installer with:

```sh
./install --monitoring
```

The monitoring flow installs the Beszel agent on macOS and Ubuntu-style Linux using Homebrew. On Linux, it installs Homebrew first if `brew` is unavailable.

Configuration comes from 1Password Environment variables synced into `~/.secrets/tokens`. Required variables are `BESZEL_KEY`, `BESZEL_TOKEN`, and `BESZEL_HUB_URL`. Run `./install --secrets` first if the local secrets file has not been created.

The installer writes `~/.config/beszel/beszel-agent.env` and the agent listens on port `45876`. If `beszel-agent` is already installed or port `45876` is in use, the flow exits successfully without changing the system.

## OpenCode

Agent skills are vendored under `home/.agents/skills` and symlinked as one subtree into `~/.agents/skills`. The installer does not fetch or remove skills at runtime.

After linking the dotfiles on either macOS or Linux:

- `opencode` connects to Basic Memory through `uvx basic-memory mcp`
- `opencode` loads Ponytail from `@dietrichgebert/ponytail` through its native plugin manager

OpenCode loads plugins at startup. After changing `home/.config/opencode/opencode.json`, quit and restart `opencode` so it installs and registers configured plugins.

If you already cloned the repo, you can still run the local installer directly:

```sh
git clone <your-repo-url> ~/.dotfiles
cd ~/.dotfiles
./install
```

## Layout

- `install` is the main entrypoint
- `.macos` handles both macOS profiles and macOS defaults
- `scripts/install/secrets.sh` syncs 1Password Environment variables to the local secrets file
- `scripts/install/monitoring.sh` installs monitoring tools such as the Beszel agent
- `scripts/install/macos_common.sh` contains shared macOS installer helpers used by both macOS entrypoints
- `scripts/install/macos_defaults.sh` contains macOS `defaults` settings applied by `.macos`
- `home/.agents/skills` contains vendored agent skills
- `.ubuntu` handles Ubuntu prerequisites and apt installs
- `home/` contains the files that get symlinked into `$HOME`
- `scripts/lib/` contains shared installer helpers

## Development Notes

- validate edited shell scripts with `bash -n path/to/script`
- common checks: `bash -n install`, `bash -n bootstrap`, `bash -n .macos`, `bash -n .ubuntu`, `bash -n scripts/install/macos_common.sh`, `bash -n scripts/install/skills.sh`
- rerun the vendored skills relink with `./install --skills`
- rerun only the macOS defaults flow with `./install --macos-defaults --macos-profile main`
- rerun only the monitoring flow with `./install --monitoring`
- validate monitoring changes with `bash -n install && bash -n scripts/install/monitoring.sh`
- smoke test the operator-facing macOS flow with `./install --macos-profile remote` and `./install --macos-profile main`
- smoke test the Ubuntu path with `./.ubuntu`
- keep vendored skills under `home/.agents/skills/<skill>/SKILL.md`
- prefer small, idempotent shell changes that preserve the existing `log_step`/`log_info`/`log_warn`/`log_error`/`log_success` output style

## Validation matrix

Shell syntax checks:

```sh
bash -n install
bash -n bootstrap
bash -n .macos
bash -n scripts/install/skills.sh
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

skills_result = run_case("skills", ["./install", "--skills"])
print(skills_result.stdout + skills_result.stderr, end="")
assert skills_result.returncode == 0
PY

./install --macos-profile invalid
./install --macos-defaults --macos-profile remote
```

The successful smoke cases use temporary PATH stubs and a temporary HOME so they stop at the profile dispatch points without touching the real machine state, while proving the `./install` entrypoint rather than direct `.macos` execution.

## Notes

- macOS App Store installs run only when `mas` is signed in
- rerunning `./install` is safe
- `yadm` is no longer part of the install flow
