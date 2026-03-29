#!/usr/bin/env bash

set -euo pipefail

resolve_macos_tailscale_pkg_url() {
  local pkg_path

  pkg_path="$({ curl -fsSL https://pkgs.tailscale.com/stable/#macos || return 1; } | grep -o 'Tailscale-[0-9.]*-macos\.pkg' | sed -n '1p')"

  if [ -z "$pkg_path" ]; then
    return 1
  fi

  printf 'https://pkgs.tailscale.com/stable/%s\n' "$pkg_path"
}

install_macos_tailscale_launcher() {
  local launcher_path="/usr/local/bin/tailscale"
  local executable_path="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
  local expected_launcher

  if [ ! -x "$executable_path" ]; then
    log_warn "Skipping Tailscale CLI launcher because $executable_path was not found."
    return
  fi

  expected_launcher=$(cat <<EOF
#!/bin/sh
exec "$executable_path" "\$@"
EOF
)

  if [ -f "$launcher_path" ] && [ "$(cat "$launcher_path")" = "$expected_launcher" ]; then
    log_info "Tailscale CLI launcher already installed"
    return
  fi

  log_info "Installing Tailscale CLI launcher"
  sudo mkdir -p /usr/local/bin
  sudo tee "$launcher_path" >/dev/null <<EOF
#!/bin/sh
exec "$executable_path" "\$@"
EOF
  sudo chmod +x "$launcher_path"
}

install_macos_tailscale() {
  local pkg_url tmp_pkg

  if [ -d /Applications/Tailscale.app ]; then
    log_info "Tailscale already installed on macOS"
  else
    pkg_url="$(resolve_macos_tailscale_pkg_url)"

    if [ -z "$pkg_url" ]; then
      log_error "Could not resolve the latest macOS Tailscale package URL."
      exit 1
    fi

    tmp_pkg="$(mktemp -t tailscale-installer).pkg"

    log_step "Installing Tailscale on macOS"
    curl -fsSL "$pkg_url" -o "$tmp_pkg"
    sudo installer -pkg "$tmp_pkg" -target / >/dev/null
    rm -f "$tmp_pkg"
  fi

  install_macos_tailscale_launcher

  if pgrep -x Tailscale >/dev/null 2>&1; then
    log_info "Tailscale already running on macOS"
    log_info "Use 'tailscale status' to verify the current session"
    return
  fi

  log_step "Starting Tailscale on macOS"
  open -a Tailscale >/dev/null 2>&1 || true
  log_info "Finish setup in the Tailscale app or with: sudo tailscale up"
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
