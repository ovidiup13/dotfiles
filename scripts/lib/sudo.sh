#!/usr/bin/env bash

set -euo pipefail

SUDO_KEEPALIVE_PID=''

acquire_sudo() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    log_error "sudo is required for this installer."
    exit 1
  fi

  log_step "Requesting administrator access"
  sudo -v

  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" >/dev/null 2>&1 || exit
  done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!

  trap release_sudo EXIT INT TERM
}

release_sudo() {
  if [ -n "$SUDO_KEEPALIVE_PID" ] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
  fi
}
