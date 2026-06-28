#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"

. "$REPO_ROOT/scripts/lib/common.sh"

export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"

load_brew_env() {
  if command_exists brew; then
    eval "$(brew shellenv)"
    return
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return
  fi

  if [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return
  fi

  log_error "Homebrew is required to install goenv."
  exit 1
}

ensure_darwin() {
  if [ "$(uname -s)" != "Darwin" ]; then
    log_error "tailscaled macOS installer only runs on Darwin."
    exit 1
  fi

  case "$(uname -m)" in
    arm64|x86_64)
      ;;
    *)
      log_error "Unsupported Darwin architecture: $(uname -m)."
      exit 1
      ;;
  esac
}

exit_if_tailscale_ssh() {
  local ssh_connection="${SSH_CONNECTION:-}"
  local tailscale_ips
  local ip

  if [ -z "$ssh_connection" ] || ! command_exists tailscale; then
    return
  fi

  tailscale_ips="$(tailscale ip 2>/dev/null || true)"
  if [ -z "$tailscale_ips" ]; then
    return
  fi

  for ip in $tailscale_ips; do
    case " $ssh_connection " in
      *" $ip "*)
        log_error "Refusing to restart Tailscale from an SSH session over Tailscale."
        exit 1
        ;;
    esac
  done
}

stop_existing_tailscale() {
  if command_exists tailscale; then
    log_step "Stopping existing Tailscale session"
    sudo tailscale down >/dev/null 2>&1 || true
  fi

  if command_exists tailscaled; then
    log_step "Uninstalling existing tailscaled service"
    sudo tailscaled uninstall-system-daemon >/dev/null 2>&1 || true
  fi

  if [ -d /Applications/Tailscale.app ]; then
    log_step "Stopping Tailscale app"
    osascript -e 'quit app "Tailscale"' >/dev/null 2>&1 || true
  fi
}

install_latest_go_with_goenv() {
  log_step "Installing latest goenv with Homebrew"
  brew update >/dev/null
  brew install goenv >/dev/null 2>&1 || brew upgrade goenv
  brew upgrade goenv >/dev/null 2>&1 || true

  export PATH="$GOENV_ROOT/bin:$GOENV_ROOT/shims:$PATH"
  eval "$(goenv init - bash)"

  log_step "Installing latest Go release with goenv"
  goenv install -s latest
  goenv global latest
  goenv rehash
}

build_tailscale() {
  log_step "Building tailscale and tailscaled from source"
  go install tailscale.com/cmd/tailscale{,d}@main
  goenv rehash || true
}

install_tailscaled_service() {
  local gopath
  local tailscaled_bin

  gopath="$(go env GOPATH)"
  tailscaled_bin="$gopath/bin/tailscaled"

  if [ ! -x "$tailscaled_bin" ]; then
    log_error "Built tailscaled binary was not found at $tailscaled_bin."
    exit 1
  fi

  log_step "Installing tailscaled as a system daemon"
  sudo "$tailscaled_bin" install-system-daemon
}

check_tailscale_status() {
  log_step "Checking Tailscale status"
  if ! tailscale status >/dev/null; then
    log_step "Starting Tailscale"
    sudo tailscale up
  fi

  if ! tailscale status >/dev/null; then
    log_error "tailscale status failed after running sudo tailscale up."
    exit 1
  fi

  log_success "tailscale status OK"
}

main() {
  ensure_darwin
  load_brew_env
  exit_if_tailscale_ssh
  stop_existing_tailscale
  install_latest_go_with_goenv
  build_tailscale
  install_tailscaled_service
  check_tailscale_status
}

main "$@"
