# Dotfiles

Cross-platform dotfiles with a single `./install` entrypoint.

## What it does

- detects whether it is running on macOS or Ubuntu
- requests `sudo` once and keeps the session alive while the install runs
- installs platform prerequisites and packages
- installs macOS agent skills listed in `packages/macos/skills.txt`
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

The bootstrap script installs the minimum prerequisites needed to clone the repo into `~/.dotfiles`, then hands off to `~/.dotfiles/install`.

For unattended installs, set `DOTFILES_GIT_NAME` and `DOTFILES_GIT_EMAIL` before running the installer.

To re-run only the macOS skills sync later, use:

```sh
./install --skills
```

To re-apply only the macOS defaults later, use:

```sh
./install --macos-defaults
```

The skills installer reads `packages/macos/skills.txt` as `<source> <skill>`, installs only those exact skills, removes unmanaged global skills, and targets `universal opencode` by default. Override agents with `DOTFILES_SKILLS_AGENTS="opencode cursor"` if needed.

If you already cloned the repo, you can still run the local installer directly:

```sh
git clone <your-repo-url> ~/.dotfiles
cd ~/.dotfiles
./install
```

## Layout

- `install` is the main entrypoint
- `.macos` handles macOS prerequisites and Homebrew installs
- `scripts/install/macos_defaults.sh` contains macOS `defaults` settings applied by `.macos`
- `packages/macos/skills.txt` lists exact Skills CLI installs as `<source> <skill>` on macOS
- `.ubuntu` handles Ubuntu prerequisites and apt installs
- `home/` contains the files that get symlinked into `$HOME`
- `scripts/lib/` contains shared installer helpers

## Development Notes

- validate edited shell scripts with `bash -n path/to/script`
- common checks: `bash -n install`, `bash -n bootstrap`, `bash -n .macos`, `bash -n .ubuntu`, `bash -n scripts/install/skills.sh`
- rerun only the skills flow with `./install --skills`
- rerun only the macOS defaults flow with `./install --macos-defaults`
- smoke test the macOS post-link stage with `./.macos --post-link`
- smoke test the Ubuntu path with `./.ubuntu`
- keep `packages/macos/skills.txt` entries to one exact `<source> <skill>` mapping per line
- prefer small, idempotent shell changes that preserve the existing `log_step`/`log_info`/`log_warn`/`log_error`/`log_success` output style

## Notes

- macOS App Store installs run only when `mas` is signed in
- rerunning `./install` is safe
- `yadm` is no longer part of the install flow
