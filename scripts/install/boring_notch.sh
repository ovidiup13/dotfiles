#!/usr/bin/env bash

set -euo pipefail

resolve_boring_notch_dmg_url() {
  printf 'https://github.com/TheBoredTeam/boring.notch/releases/latest/download/boringNotch.dmg\n'
}

clear_boring_notch_quarantine() {
  local app_path="/Applications/boringNotch.app"

  if [ ! -d "$app_path" ]; then
    log_warn "Skipping Boring Notch quarantine cleanup because $app_path was not found."
    return
  fi

  log_info "Allowing Boring Notch to launch outside Gatekeeper"
  sudo xattr -dr com.apple.quarantine "$app_path" >/dev/null 2>&1 || true
}

install_macos_boring_notch() {
  local app_path="/Applications/boringNotch.app"
  local dmg_url tmp_dmg mount_point mounted_app

  if [ -d "$app_path" ]; then
    log_info "Boring Notch already installed on macOS"
    clear_boring_notch_quarantine
    return
  fi

  dmg_url="$(resolve_boring_notch_dmg_url)"

  if [ -z "$dmg_url" ]; then
    log_error "Could not resolve the Boring Notch macOS download URL."
    exit 1
  fi

  tmp_dmg="$(mktemp -t boring-notch-installer).dmg"
  mount_point=""

  cleanup_boring_notch_installer() {
    if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
      hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    fi

    rm -f "$tmp_dmg"
  }

  trap cleanup_boring_notch_installer RETURN

  log_step "Installing Boring Notch on macOS"
  curl -fL "$dmg_url" -o "$tmp_dmg"

  mount_point="$(hdiutil attach -nobrowse -readonly "$tmp_dmg" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

  if [ -z "$mount_point" ]; then
    log_error "Could not mount the Boring Notch disk image."
    exit 1
  fi

  mounted_app="$mount_point/boringNotch.app"

  if [ ! -d "$mounted_app" ]; then
    log_error "Could not find boringNotch.app in the mounted disk image."
    exit 1
  fi

  sudo rm -rf "$app_path"
  sudo ditto "$mounted_app" "$app_path"

  clear_boring_notch_quarantine
  log_info "Launch Boring Notch from Applications to finish any in-app permissions setup."
}
