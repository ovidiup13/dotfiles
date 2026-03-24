#!/usr/bin/env bash

set -euo pipefail

clone_or_update_repo() {
  local repo_url="$1"
  local dest="$2"

  if [ -d "$dest/.git" ]; then
    log_info "Updating $(basename "$dest")"
    git -C "$dest" pull --ff-only >/dev/null
    return
  fi

  log_info "Installing $(basename "$dest")"
  mkdir -p "$(dirname "$dest")"
  git clone --depth=1 "$repo_url" "$dest" >/dev/null
}

install_macos_oh_my_zsh() {
  local zsh_root="$HOME/.oh-my-zsh"
  local custom_root="${ZSH_CUSTOM:-$zsh_root/custom}"
  local themes_root="$custom_root/themes"
  local plugins_root="$custom_root/plugins"

  if ! command_exists zsh; then
    log_error "zsh is required for the macOS shell setup."
    exit 1
  fi

  log_step "Installing macOS shell tooling"
  clone_or_update_repo "https://github.com/ohmyzsh/ohmyzsh.git" "$zsh_root"
  clone_or_update_repo "https://github.com/mroth/evalcache.git" "$plugins_root/evalcache"
  clone_or_update_repo "https://github.com/zsh-users/zsh-autosuggestions.git" "$plugins_root/zsh-autosuggestions"
  clone_or_update_repo "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$plugins_root/zsh-syntax-highlighting"
  clone_or_update_repo "https://github.com/spaceship-prompt/spaceship-prompt.git" "$themes_root/spaceship-prompt"

  if [ ! -L "$themes_root/spaceship.zsh-theme" ]; then
    ln -snf "$themes_root/spaceship-prompt/spaceship.zsh-theme" "$themes_root/spaceship.zsh-theme"
  fi
}

verify_ubuntu_shell_prereqs() {
  log_step "Verifying Ubuntu shell prerequisites"

  if ! command_exists zsh; then
    log_error "zsh is required but was not installed."
    exit 1
  fi
}

set_ubuntu_default_shell() {
  local zsh_path current_shell user_name

  zsh_path="$(command -v zsh)"
  user_name="${SUDO_USER:-$(id -un)}"
  current_shell="$(getent passwd "$user_name" | cut -d: -f7)"

  if [ "$current_shell" = "$zsh_path" ]; then
    log_info "Default shell already set to zsh"
    return
  fi

  log_step "Setting default shell to zsh"
  sudo chsh -s "$zsh_path" "$user_name"
  log_success "Default shell updated for $user_name"
}
