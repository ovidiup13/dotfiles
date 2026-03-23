#!/usr/bin/env bash

set -euo pipefail

install_macos_tailscale() {
  if ! command_exists brew; then
    log_error "Homebrew is required for the macOS Tailscale install."
    exit 1
  fi

  if ! brew list --formula tailscale >/dev/null 2>&1; then
    log_warn "Skipping Tailscale startup because the Homebrew formula is not installed yet."
    return
  fi

  if command_exists tailscale; then
    log_info "Tailscale already installed on macOS"
  else
    log_warn "Skipping Tailscale startup because the tailscale command is not available yet."
    return
  fi

  if pgrep -x tailscaled >/dev/null 2>&1; then
    log_info "Tailscale already running on macOS"
    log_info "Use 'tailscale status' to verify the current session"
    return
  fi

  log_step "Starting Tailscale on macOS"
  sudo brew services start tailscale >/dev/null
  log_info "Finish setup with: sudo tailscale up"
}

install_ubuntu_tailscale() {
  if command_exists tailscale; then
    log_info "Tailscale already installed"
  else
    log_step "Installing Tailscale on Ubuntu"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  if pgrep -x tailscaled >/dev/null 2>&1; then
    log_info "Tailscale already running on Ubuntu"
    log_info "Use 'tailscale status' to verify the current session"
    return
  fi

  if command_exists systemctl; then
    if systemctl is-active --quiet tailscaled; then
      log_info "Tailscale already running on Ubuntu"
      log_info "Use 'tailscale status' to verify the current session"
      return
    fi

    log_step "Starting Tailscale on Ubuntu"
    sudo systemctl enable --now tailscaled >/dev/null
  else
    log_warn "Skipping automatic Tailscale service startup because systemctl is not available."
  fi

  log_info "Finish setup with: sudo tailscale up"
}
