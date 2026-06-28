#!/usr/bin/env bash

set -euo pipefail

export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"

install_macos_runtimes() {
  install_uv
  install_basic_memory
  install_vp_cli
  install_rustup
  install_goenv_latest
}

install_ubuntu_runtimes() {
  install_uv
  install_basic_memory
  install_rustup
  install_bun
  install_volta
  install_node_lts_with_volta
  install_opencode
}

load_uv_env() {
  if [ -r "$HOME/.local/bin/env" ]; then
    . "$HOME/.local/bin/env"
  fi
}

install_uv() {
  if command_exists uv; then
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping uv setup because curl is not installed."
    return 1
  fi

  log_step "Installing uv from astral.sh"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  load_uv_env

  if ! command_exists uv; then
    log_warn "uv was installed but is not available in this shell."
    return 1
  fi
}

install_basic_memory() {
  if command_exists basic-memory; then
    return 0
  fi

  if ! install_uv; then
    log_warn "Skipping Basic Memory setup because uv is not available."
    return 1
  fi

  load_uv_env

  log_step "Installing Basic Memory with uv"
  uv tool install basic-memory
}

load_cargo_env() {
  if [ -r "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
  fi
}

install_rustup() {
  load_cargo_env

  if command_exists rustup; then
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping Rust setup because curl is not installed."
    return 1
  fi

  log_step "Installing Rust with rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  load_cargo_env

  if ! command_exists rustup; then
    log_warn "Rust was installed but rustup is not available in this shell."
    return 1
  fi
}

load_bun_env() {
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  PATH="$BUN_INSTALL/bin:$PATH"
}

install_bun() {
  load_bun_env

  if command_exists bun; then
    log_step "Upgrading Bun"
    bun upgrade
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping Bun setup because curl is not installed."
    return 1
  fi

  log_step "Installing Bun"
  curl -fsSL https://bun.com/install | bash
  load_bun_env

  if ! command_exists bun; then
    log_warn "Bun was installed but is not available in this shell."
    return 1
  fi
}

load_volta_env() {
  export VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
  if [ -d "$VOLTA_HOME/bin" ]; then
    PATH="$VOLTA_HOME/bin:$PATH"
  fi
}

install_volta() {
  load_volta_env

  if command_exists volta; then
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping Volta setup because curl is not installed."
    return 1
  fi

  log_step "Installing Volta"
  curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
  load_volta_env

  if ! command_exists volta; then
    log_warn "Volta was installed but is not available in this shell."
    return 1
  fi
}

install_node_lts_with_volta() {
  if ! install_volta; then
    log_warn "Skipping Node.js LTS setup because Volta is not available."
    return 1
  fi

  load_volta_env

  log_step "Installing Node.js LTS with Volta"
  volta install node@lts
}

load_opencode_env() {
  if [ -d "$HOME/.opencode/bin" ]; then
    PATH="$HOME/.opencode/bin:$PATH"
  fi
}

install_opencode() {
  load_opencode_env

  if command_exists opencode; then
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping opencode setup because curl is not installed."
    return 1
  fi

  log_step "Installing opencode"
  curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
  load_opencode_env

  if ! command_exists opencode; then
    log_warn "opencode was installed but is not available in this shell."
    return 1
  fi
}

install_vp_cli() {
  local vp_install_dir vp_install_home

  if command_exists vp; then
    return 0
  fi

  if ! command_exists curl; then
    log_warn "Skipping Vite+ setup because curl is not installed."
    return 1
  fi

  log_step "Installing Vite+ vp"
  vp_install_dir="$HOME/.vite-plus"
  vp_install_home="$(mktemp -d)"
  if ! curl -fsSL https://vite.plus | HOME="$vp_install_home" VP_HOME="$vp_install_dir" VP_NODE_MANAGER=yes bash; then
    rm -rf "$vp_install_home"
    return 1
  fi
  rm -rf "$vp_install_home"

  if [ -r "$HOME/.vite-plus/env" ]; then
    . "$HOME/.vite-plus/env"
  fi

  if ! command_exists vp; then
    log_warn "Skipping Node.js runtime setup because vp is not available after installation."
    return 1
  fi
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
