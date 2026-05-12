#!/usr/bin/env bash

set -euo pipefail

export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"

install_macos_runtimes() {
  install_vp_node_lts
  install_goenv_latest
}

install_vp_cli() {
  if command_exists vp; then
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping Vite+ setup because curl is not installed."
    return 1
  fi

  log_step "Installing Vite+ vp"
  curl -fsSL https://vite.plus | bash

  if [ -r "$HOME/.vite-plus/env" ]; then
    . "$HOME/.vite-plus/env"
  fi

  if ! command_exists vp; then
    log_warn "Skipping Node.js runtime setup because vp is not available after installation."
    return 1
  fi
}

install_vp_node_lts() {
  if ! install_vp_cli; then
    return
  fi

  log_step "Installing Node.js LTS with vp"
  vp env setup --refresh
  vp env on
  vp env default lts
  vp env install lts
}

install_goenv_latest() {
  if ! command_exists goenv; then
    log_warn "Skipping Go runtime setup because goenv is not installed."
    return
  fi

  log_step "Installing latest Go release with goenv"
  goenv install -s latest
  goenv global latest
  goenv rehash
}
