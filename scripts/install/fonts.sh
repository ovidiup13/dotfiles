#!/usr/bin/env bash

set -euo pipefail

install_ubuntu_firacode_nerd_font() {
  local font_dir="$HOME/.local/share/fonts/FiraCodeNerdFont"
  local zip_path

  if command_exists fc-list && fc-list : family | grep -qi 'FiraCode Nerd Font'; then
    log_info "FiraCode Nerd Font already installed"
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping FiraCode Nerd Font setup because curl is not installed."
    return 1
  fi

  if ! command_exists unzip; then
    log_warn "Skipping FiraCode Nerd Font setup because unzip is not installed."
    return 1
  fi

  zip_path="$(mktemp -t firacode-nerd-font).zip"

  log_step "Installing FiraCode Nerd Font"
  mkdir -p "$font_dir"
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -o "$zip_path"
  unzip -oq "$zip_path" -d "$font_dir"
  rm -f "$zip_path"

  if command_exists fc-cache; then
    fc-cache -f "$font_dir" >/dev/null
  else
    log_warn "Skipping font cache refresh because fc-cache is not installed."
  fi
}
