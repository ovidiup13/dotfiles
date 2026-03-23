#!/usr/bin/env bash

set -euo pipefail

export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"

install_macos_runtimes() {
  install_fnm_node_lts
  install_goenv_latest
}

install_fnm_node_lts() {
  if ! command_exists fnm; then
    log_warn "Skipping Node.js runtime setup because fnm is not installed."
    return
  fi

  log_step "Installing latest Node.js LTS with fnm"
  fnm install --lts --corepack-enabled
  fnm default lts-latest
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
