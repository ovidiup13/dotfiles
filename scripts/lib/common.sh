#!/usr/bin/env bash

set -euo pipefail

log_step() {
  printf '\n==> %s\n' "$*"
}

log_info() {
  printf '  - %s\n' "$*"
}

log_warn() {
  printf '  ! %s\n' "$*"
}

log_error() {
  printf '  x %s\n' "$*" >&2
}

log_success() {
  printf '  + %s\n' "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_not_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    log_error "Run this installer as your normal user, not as root."
    exit 1
  fi
}

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      printf 'macos\n'
      ;;
    Linux)
      if [ -r /etc/os-release ] && grep -E '^(ID|ID_LIKE)=' /etc/os-release | grep -Eq '(ubuntu|debian)'; then
        printf 'ubuntu\n'
      else
        printf 'unknown\n'
      fi
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}
