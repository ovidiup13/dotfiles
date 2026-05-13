#!/usr/bin/env bash

set -euo pipefail

SECRETS_FILE_RELATIVE=".secrets/tokens"
RESOLVED_1PASSWORD_ENVIRONMENT_ID=""

read_stored_1password_environment_id() {
  local secrets_file="$1"
  local stored_environment_id

  if [ ! -f "$secrets_file" ]; then
    return
  fi

  stored_environment_id="$({ grep '^DOTFILES_1PASSWORD_ENVIRONMENT=' "$secrets_file" || true; } | tail -n 1)"
  stored_environment_id="${stored_environment_id#DOTFILES_1PASSWORD_ENVIRONMENT=}"

  if [ -n "$stored_environment_id" ]; then
    RESOLVED_1PASSWORD_ENVIRONMENT_ID="$stored_environment_id"
  fi
}

prompt_for_1password_environment_id() {
  local environment_id

  if [ ! -t 1 ] || [ ! -r /dev/tty ]; then
    log_error "Missing 1Password Environment ID. Run interactively, set DOTFILES_1PASSWORD_ENVIRONMENT, pass --1password-environment <id>, or sync once to create $HOME/$SECRETS_FILE_RELATIVE."
    exit 1
  fi

  read -r -p "1Password Environment ID: " environment_id < /dev/tty

  if [ -z "$environment_id" ]; then
    log_error "1Password Environment ID cannot be empty."
    exit 1
  fi

  RESOLVED_1PASSWORD_ENVIRONMENT_ID="$environment_id"
}

resolve_1password_environment_id() {
  local environment_id="$1"
  local secrets_file="$2"

  RESOLVED_1PASSWORD_ENVIRONMENT_ID=""

  if [ -n "$environment_id" ]; then
    RESOLVED_1PASSWORD_ENVIRONMENT_ID="$environment_id"
    return
  fi

  read_stored_1password_environment_id "$secrets_file"

  if [ -n "$RESOLVED_1PASSWORD_ENVIRONMENT_ID" ]; then
    return
  fi

  prompt_for_1password_environment_id
}

sync_1password_secrets() {
  local environment_id="${1:-}"
  local secrets_file="$HOME/$SECRETS_FILE_RELATIVE"
  local secrets_dir
  local tmp_file

  if ! command_exists op; then
    log_error "1Password CLI is not installed. Run ./install first or install op manually."
    exit 1
  fi

  secrets_dir="$(dirname "$secrets_file")"
  mkdir -p "$secrets_dir"
  chmod 700 "$secrets_dir"

  if [ -d "$secrets_file" ]; then
    log_error "Secrets file path is a directory: $secrets_file"
    exit 1
  fi

  resolve_1password_environment_id "$environment_id" "$secrets_file"
  environment_id="$RESOLVED_1PASSWORD_ENVIRONMENT_ID"

  tmp_file="$(mktemp "$secrets_dir/tokens.XXXXXX")"
  chmod 600 "$tmp_file"
  trap 'rm -f "$tmp_file"' EXIT HUP INT TERM

  printf 'DOTFILES_1PASSWORD_ENVIRONMENT=%s\n' "$environment_id" > "$tmp_file"

  if ! op environment read "$environment_id" >> "$tmp_file"; then
    rm -f "$tmp_file"
    log_error "Failed to read 1Password Environment: $environment_id"
    exit 1
  fi

  if [ "$(wc -l < "$tmp_file")" -le 1 ]; then
    rm -f "$tmp_file"
    log_error "1Password Environment returned no variables: $environment_id"
    exit 1
  fi

  mv "$tmp_file" "$secrets_file"
  trap - EXIT HUP INT TERM
  chmod 600 "$secrets_file"
  log_success "Wrote 1Password Environment variables to $secrets_file"
}
