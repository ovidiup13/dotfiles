#!/usr/bin/env bash

set -euo pipefail

install_macos_ollama() {
  if command_exists ollama; then
    log_info "Ollama already installed"
    return
  fi

  log_step "Installing Ollama"
  curl -fsSL https://ollama.com/install.sh | sh
}
