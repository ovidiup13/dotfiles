# Dotfiles

Cross-platform dotfiles and machine bootstrap with one installer CLI:

```sh
./install
```

The installer is a small Bash shim plus a Bun/TypeScript CLI. Bash remains only where it is useful for fresh-machine bootstrap and OS package-manager work; installer planning, command parsing, profile selection, dotfile linking, and Git identity setup live in `src/install.ts`.

## Install a new machine

Personal machine, default profile:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ovidiup13/dotfiles/main/bootstrap)"
```

Worker machine:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ovidiup13/dotfiles/main/bootstrap)" -- --profile worker
```

The bootstrap script installs only the minimum prerequisites required to clone or update the repo at `~/.dotfiles`, then hands off to `~/.dotfiles/install`.

## Profiles

Two profile names are supported:

- `personal`: full local workstation setup. On macOS this includes shared CLI tools, runtimes, shell setup, GUI apps, Mac App Store apps, macOS defaults, and personal-only installers such as Tailscale, Ollama, and Boring Notch.
- `worker`: CLI/devtools setup for remote or disposable machines. On macOS this uses the lighter worker package path and skips personal-only GUI/defaults work.

Use `--profile` everywhere:

```sh
./install --profile personal
./install --profile worker
./install check --profile worker
```

## Installer commands

```sh
./install                 # full install, re-apply, or upgrade path
./install apply           # same as ./install
./install check           # show detected platform, architecture, profile, and plan
./install doctor          # same as check
./install link            # re-link files from home/ into $HOME
./install secrets         # sync 1Password Environment secrets
./install skills          # run macOS post-link skills and agent setup
./install macos-defaults  # apply macOS defaults; personal profile only
```

`--dry-run` prints dispatcher-level commands and link operations without applying them:

```sh
./install --dry-run --profile worker
./install link --dry-run
./install skills --dry-run --profile worker
```

## Configuration

Flags override environment variables. Common environment variables:

| Variable | Purpose |
| --- | --- |
| `DOTFILES_PROFILE` | Default profile: `personal` or `worker` |
| `DOTFILES_PLATFORM` | Platform override for planning: `auto`, `macos`, `ubuntu`, `linux`, or `windows` |
| `DOTFILES_DRY_RUN` | Set to `1`, `true`, `yes`, or `on` to enable dry-run |
| `DOTFILES_GIT_NAME` | Noninteractive Git `user.name` for `~/.gitconfig.local` |
| `DOTFILES_GIT_EMAIL` | Noninteractive Git `user.email` for `~/.gitconfig.local` |
| `DOTFILES_1PASSWORD_ENVIRONMENT` | 1Password Environment ID for secrets sync |
| `DOTFILES_SKILLS_AGENTS` | Space-separated Skills CLI agent targets; default is `universal opencode` |

Example unattended install:

```sh
DOTFILES_PROFILE=worker \
DOTFILES_GIT_NAME="Your Name" \
DOTFILES_GIT_EMAIL="you@example.com" \
./install
```

## What gets installed

All profiles:

- platform prerequisites
- shared CLI packages from `packages/base/Brewfile` on macOS or `packages/ubuntu/apt.txt` on Ubuntu-style systems
- `uv`
- Basic Memory via `uv`
- shell configuration and managed dotfiles from `home/`
- local Git identity in `~/.gitconfig.local` when configured
- 1Password Environment secrets in `~/.secrets/tokens` when synced

macOS `personal`:

- `packages/macos/Brewfile`
- `packages/macos/Brewfile.mas`
- GUI apps, fonts, and local workstation tools
- macOS defaults
- personal-only app installers such as Tailscale, Ollama, and Boring Notch

macOS `worker`:

- `packages/macos/Brewfile.remote`
- shared runtimes and shell setup
- GitHub SSH key setup
- macOS post-link Skills and OpenCode agent setup

Ubuntu-style Linux:

- apt packages from `packages/ubuntu/apt.txt`
- Ubuntu runtime and shell setup
- Tailscale via the upstream install path

Windows is recognized by the CLI planning layer but does not have an install provider yet.

## Secrets

Secrets are managed outside the repository with 1Password Environments.

```sh
./install secrets --1password-environment <environment-id>
```

Or with an environment variable:

```sh
DOTFILES_1PASSWORD_ENVIRONMENT=<environment-id> ./install secrets
```

The secrets sync requires the `op` CLI to be installed and authenticated. It writes `DOTFILES_1PASSWORD_ENVIRONMENT=<environment-id>` plus variables returned by `op environment read <environment-id>` to `~/.secrets/tokens`, sets `~/.secrets` to mode `700`, and sets the generated file to mode `600`.

Full `./install` runs secrets sync after package setup and dotfile linking. If no Environment ID is available, it prompts interactively.

## Dotfile linking

Files under `home/` are linked into `$HOME` by `./install link` or the full install path.

Existing non-managed targets are moved to:

```text
~/.dotfiles-backups/<timestamp>/
```

Then the managed symlink is created.

## OpenCode and Skills

On macOS, the post-link flow:

- syncs exact Skills CLI entries from `packages/macos/skills.txt`
- removes unmanaged global skills
- installs Oh My OpenAgent with `bunx oh-my-openagent install --no-tui --skip-auth`
- verifies the local OpenCode setup

Run it directly with:

```sh
./install skills --profile personal
./install skills --profile worker
```

After linking, `opencode` loads `oh-my-openagent@latest` from the checked-in config and connects to Basic Memory through `uvx basic-memory mcp`.

## Repository layout

```text
bootstrap                  fresh-machine shell bootstrap
install                    Bash shim that ensures Bun and runs src/install.ts
src/install.ts             installer CLI, planning, linking, Git identity, orchestration
.macos                     macOS personal setup and shared macOS maintenance modes
.macos-remote              macOS worker setup
.ubuntu                    Ubuntu-style setup
scripts/lib/               shared shell helpers
scripts/install/           platform and integration provider scripts
packages/base/Brewfile     shared Homebrew packages
packages/macos/            macOS package manifests and skills manifest
packages/ubuntu/apt.txt    Ubuntu package manifest
home/                      managed files linked into $HOME
```

## Development and validation

Shell syntax checks:

```sh
bash -n install
bash -n bootstrap
bash -n .macos
bash -n .macos-remote
bash -n .ubuntu
bash -n scripts/install/skills.sh
bash -n scripts/install/secrets.sh
```

TypeScript CLI check:

```sh
bun build src/install.ts --target bun --outfile /tmp/dotfiles-install-check.js
```

Non-mutating smoke checks:

```sh
./install --help
./install check
./install check --profile worker
./install check --platform ubuntu --profile worker
./install --dry-run --profile worker
./install link --dry-run
./install secrets --dry-run --1password-environment env-test
./install skills --dry-run --profile worker
./install macos-defaults --dry-run --profile personal
```

Expected guard failures:

```sh
./install check --profile invalid
./install macos-defaults --dry-run --profile worker
```

## Notes

- Re-running `./install` is intended to be safe and idempotent.
- The CLI accepts only `personal` and `worker` profiles.
- Old compatibility flags and profile names are intentionally unsupported.
- macOS App Store installs run only when `mas` is available and signed in.
- ADRs for the installer runtime and command contract are stored in the notes project under `adr/`.
