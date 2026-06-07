#!/usr/bin/env bash

set -euo pipefail

ensure_ubuntu_onepassword_repo_prereqs() {
  if command_exists curl && command_exists gpg; then
    log_info "1Password APT repo prerequisites already installed"
    return
  fi

  log_step "Installing 1Password APT repo prerequisites"
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
}

onepassword_keyring_has_required_key() {
  local keyring_path="$1"
  local required_fingerprint="$2"

  [ -f "$keyring_path" ] || return 1

  sudo gpg --show-keys --with-colons "$keyring_path" 2>/dev/null | grep -q "^fpr:::::::::${required_fingerprint}:"
}

setup_ubuntu_onepassword_cli_beta_repo() {
  local arch repo_url key_url key_fingerprint keyring_dir keyring_path repo_path prefs_dir prefs_path repo_line

  if [ "$(detect_platform)" != "ubuntu" ]; then
    return
  fi

  arch="$(dpkg --print-architecture)"
  repo_url="https://downloads.1password.com/linux/debian/${arch}"
  key_url="https://downloads.1password.com/linux/keys/1password.asc"
  key_fingerprint="3FEF9748469ADBE15DA7CA80AC2D62742012EA22"
  keyring_dir="/usr/share/keyrings"
  keyring_path="${keyring_dir}/1password-archive-keyring.gpg"
  repo_path="/etc/apt/sources.list.d/1password-beta.list"
  prefs_dir="/etc/apt/preferences.d"
  prefs_path="${prefs_dir}/1password-beta.pref"
  repo_line="deb [arch=${arch} signed-by=${keyring_path}] ${repo_url} beta main"

  ensure_ubuntu_onepassword_repo_prereqs

  if onepassword_keyring_has_required_key "$keyring_path" "$key_fingerprint"; then
    log_info "1Password archive keyring already installed"
  else
    log_step "Installing 1Password archive keyring"
    sudo mkdir -p "$keyring_dir"
    curl -fsSL "$key_url" | sudo gpg --batch --yes --dearmor -o "$keyring_path"

    if ! onepassword_keyring_has_required_key "$keyring_path" "$key_fingerprint"; then
      log_error "Installed 1Password archive keyring is missing the expected signing key."
      exit 1
    fi
  fi

  if [ -f "$repo_path" ] && [ "$(sudo cat "$repo_path")" = "$repo_line" ]; then
    log_info "1Password beta APT source already configured"
  else
    log_step "Configuring 1Password beta APT source"
    printf '%s\n' "$repo_line" | sudo tee "$repo_path" >/dev/null
  fi

  sudo rm -f /etc/apt/sources.list.d/1password.list

  sudo mkdir -p "$prefs_dir"
  if [ -f "$prefs_path" ] && [ "$(sudo cat "$prefs_path")" = $'Package: 1password-cli\nPin: release a=beta\nPin-Priority: 700' ]; then
    log_info "1Password beta APT preference already configured"
  else
    log_step "Preferring the 1Password beta CLI package"
    sudo tee "$prefs_path" >/dev/null <<'EOF'
Package: 1password-cli
Pin: release a=beta
Pin-Priority: 700
EOF
  fi
}
