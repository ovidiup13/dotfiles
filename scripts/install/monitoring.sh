#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! declare -F log_step >/dev/null || ! declare -F log_info >/dev/null || ! declare -F log_error >/dev/null || ! declare -F log_success >/dev/null || ! declare -F command_exists >/dev/null; then
  . "$REPO_ROOT/scripts/lib/common.sh"
fi

if ! declare -F ensure_homebrew >/dev/null || ! declare -F load_homebrew_env >/dev/null; then
  . "$REPO_ROOT/scripts/install/homebrew.sh"
fi

if [ -z "${SECRETS_FILE_RELATIVE+x}" ]; then
  . "$REPO_ROOT/scripts/install/secrets.sh"
fi

BESZEL_AGENT_PORT="45876"
BESZEL_AGENT_ENV_FILE_RELATIVE=".config/beszel/beszel-agent.env"
BESZEL_AGENT_CACHE_DIR_RELATIVE=".cache/beszel"

beszel_agent_installed() {
  command_exists beszel-agent
}

beszel_agent_port_in_use() {
  if command_exists lsof; then
    lsof -nP -iTCP:"$BESZEL_AGENT_PORT" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi

  if command_exists ss; then
    ss -ltn 2>/dev/null | grep -Eq "[.:]$BESZEL_AGENT_PORT[[:space:]]"
    return
  fi

  if command_exists netstat; then
    netstat -an 2>/dev/null | grep -Eq "[.:]$BESZEL_AGENT_PORT[[:space:]].*LISTEN"
    return
  fi

  return 1
}

load_secret_assignment() {
  local line="$1"
  local name
  local value

  case "$line" in
    ""|\#*)
      return
      ;;
    export\ *)
      line="${line#export }"
      ;;
  esac

  case "$line" in
    *=*)
      ;;
    *)
      return
      ;;
  esac

  name="${line%%=*}"
  value="${line#*=}"

  case "$name" in
    BESZEL_KEY|BESZEL_TOKEN|BESZEL_HUB_URL)
      ;;
    *)
      return
      ;;
  esac

  case "$value" in
    "\""*"\"") value="${value#\"}"; value="${value%\"}" ;;
    "'"*"'") value="${value#\'}"; value="${value%\'}" ;;
  esac

  printf -v "$name" '%s' "$value"
}

load_dotfiles_secrets() {
  local secrets_file="$HOME/$SECRETS_FILE_RELATIVE"
  local line

  if [ ! -f "$secrets_file" ]; then
    log_error "Missing 1Password Environment secrets file: $secrets_file. Run ./install --secrets first."
    exit 1
  fi

  unset BESZEL_KEY BESZEL_TOKEN BESZEL_HUB_URL

  while IFS= read -r line || [ -n "$line" ]; do
    load_secret_assignment "$line"
  done < "$secrets_file"
}

require_beszel_environment() {
  if [ -z "${BESZEL_KEY:-}" ]; then
    log_error "Missing BESZEL_KEY in $HOME/$SECRETS_FILE_RELATIVE."
    exit 1
  fi

  if [ -z "${BESZEL_TOKEN:-}" ]; then
    log_error "Missing BESZEL_TOKEN in $HOME/$SECRETS_FILE_RELATIVE."
    exit 1
  fi

  if [ -z "${BESZEL_HUB_URL:-}" ]; then
    log_error "Missing BESZEL_HUB_URL in $HOME/$SECRETS_FILE_RELATIVE."
    exit 1
  fi
}

quote_shell_value() {
  local value="$1"

  printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}

write_beszel_agent_env() {
  local env_file="$HOME/$BESZEL_AGENT_ENV_FILE_RELATIVE"
  local env_dir
  local old_umask

  env_dir="$(dirname "$env_file")"
  mkdir -p "$env_dir"
  chmod 700 "$env_dir"

  old_umask="$(umask)"
  umask 077
  {
    printf 'KEY=%s\n' "$(quote_shell_value "$BESZEL_KEY")"
    printf 'TOKEN=%s\n' "$(quote_shell_value "$BESZEL_TOKEN")"
    printf 'HUB_URL=%s\n' "$(quote_shell_value "$BESZEL_HUB_URL")"
    printf 'LISTEN=%s\n' "$BESZEL_AGENT_PORT"
  } > "$env_file"
  umask "$old_umask"
  chmod 600 "$env_file"
}

ensure_beszel_agent_directories() {
  local cache_dir="$HOME/$BESZEL_AGENT_CACHE_DIR_RELATIVE"

  mkdir -p "$cache_dir"
  chmod 700 "$cache_dir"
}

install_beszel_agent_with_brew() {
  ensure_homebrew

  if ! load_homebrew_env; then
    log_error "Homebrew is required but was not found after installation."
    exit 1
  fi

  log_step "Installing Beszel agent with Homebrew"
  brew tap henrygd/beszel
  brew install beszel-agent
}

start_beszel_agent_service() {
  log_step "Starting Beszel agent service"
  brew services start beszel-agent
}

install_monitoring_tools() {
  local platform="$1"

  case "$platform" in
    macos|ubuntu)
      ;;
    *)
      log_error "Monitoring tools are supported only on macOS and Ubuntu-style Linux."
      exit 1
      ;;
  esac

  load_homebrew_env >/dev/null 2>&1 || true

  if beszel_agent_installed; then
    log_info "Beszel agent already installed; skipping monitoring setup."
    return
  fi

  if beszel_agent_port_in_use; then
    log_info "Port $BESZEL_AGENT_PORT is already in use; skipping monitoring setup."
    return
  fi

  load_dotfiles_secrets
  require_beszel_environment
  install_beszel_agent_with_brew
  write_beszel_agent_env
  ensure_beszel_agent_directories
  start_beszel_agent_service
  log_success "Monitoring tools installed"
}
