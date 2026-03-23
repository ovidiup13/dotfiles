# Dotfiles

Cross-platform dotfiles with a single `./install` entrypoint.

## What it does

- detects whether it is running on macOS or Ubuntu
- requests `sudo` once and keeps the session alive while the install runs
- installs platform prerequisites and packages
- installs macOS agent skills listed in `packages/macos/skills.txt`
- symlinks managed files from `home/` into `$HOME`
- symlinks `home/.agents/.skill-lock.json` into `~/.agents/.skill-lock.json`
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

The skills installer uses `skills add --yes -g --skill '*'` and targets `universal opencode` by default. Override agents with `DOTFILES_SKILLS_AGENTS="opencode cursor"` if needed.

If you already cloned the repo, you can still run the local installer directly:

```sh
git clone <your-repo-url> ~/.dotfiles
cd ~/.dotfiles
./install
```

## Layout

- `install` is the main entrypoint
- `.macos` handles macOS prerequisites and Homebrew installs
- `packages/macos/skills.txt` lists the Skills CLI sources to install on macOS
- `.ubuntu` handles Ubuntu prerequisites and apt installs
- `home/` contains the files that get symlinked into `$HOME`
- `scripts/lib/` contains shared installer helpers

## Notes

- macOS App Store installs run only when `mas` is signed in
- rerunning `./install` is safe
- `yadm` is no longer part of the install flow
