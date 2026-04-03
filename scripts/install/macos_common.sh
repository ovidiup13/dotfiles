#!/usr/bin/env bash

set -euo pipefail

ensure_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    log_info "Xcode Command Line Tools already installed"
    return
  fi

  log_step "Installing Xcode Command Line Tools"
  xcode-select --install >/dev/null 2>&1 || true
  log_warn "Finish the Command Line Tools prompt if macOS shows it, then rerun ./install if needed."
}

ensure_github_ssh_key() {
  local ssh_dir="$HOME/.ssh"
  local key_path="$ssh_dir/github"
  local config_file="$ssh_dir/config"
  local comment

  if ! command_exists ssh-keygen; then
    log_error "ssh-keygen is required to generate the GitHub SSH key."
    exit 1
  fi

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [ -f "$key_path" ]; then
    log_info "GitHub SSH key already exists at $key_path"
    return
  fi

  comment="${DOTFILES_GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
  if [ -z "$comment" ]; then
    comment="github"
  fi

  log_step "Generating GitHub SSH key"
  ssh-keygen -t ed25519 -C "$comment" -f "$key_path" -N ""

  touch "$config_file"
  chmod 600 "$config_file"

  if ! grep -q 'IdentityFile ~/.ssh/github' "$config_file"; then
    cat >> "$config_file" <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/github
EOF
  fi

  if command_exists ssh-add; then
    ssh-add --apple-use-keychain "$key_path" >/dev/null 2>&1 || ssh-add "$key_path" >/dev/null 2>&1 || true
  fi

  log_info "Copy the public key with: pbcopy < $key_path.pub"
}
