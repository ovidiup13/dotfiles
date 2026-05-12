#!/usr/bin/env bash

set -euo pipefail

ensure_homebrew() {
  if command_exists brew; then
    return
  fi

  log_step "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

load_homebrew_env() {
  local brew_bin

  if command_exists brew; then
    eval "$(brew shellenv)"
    return 0
  fi

  for brew_bin in \
    /home/linuxbrew/.linuxbrew/bin/brew \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew
  do
    if [ -x "$brew_bin" ]; then
      eval "$("$brew_bin" shellenv)"
      return 0
    fi
  done

  return 1
}

run_brew_bundle() {
  local brewfile="$1"

  if brew bundle --file "$brewfile"; then
    return 0
  fi

  log_warn "brew bundle failed for $brewfile; retrying without Homebrew API metadata."
  HOMEBREW_NO_INSTALL_FROM_API=1 brew bundle --file "$brewfile"
}
