#!/usr/bin/env bash

set -euo pipefail

GIT_IDENTITY_FILE_RELATIVE=".gitconfig.local"

read_existing_identity_file() {
  local identity_file="$HOME/$GIT_IDENTITY_FILE_RELATIVE"
  local key="$1"

  if [ ! -f "$identity_file" ]; then
    return
  fi

  git config --file "$identity_file" "$key" 2>/dev/null || true
}

prompt_with_default() {
  local prompt="$1"
  local default_value="$2"
  local reply

  if [ -n "$default_value" ]; then
    read -r -p "$prompt [$default_value]: " reply
    printf '%s\n' "${reply:-$default_value}"
    return
  fi

  read -r -p "$prompt: " reply
  printf '%s\n' "$reply"
}

write_git_identity() {
  local git_name="$1"
  local git_email="$2"
  local identity_file="$HOME/$GIT_IDENTITY_FILE_RELATIVE"

  cat > "$identity_file" <<EOF
[user]
	name = $git_name
	email = $git_email
EOF

  log_success "Wrote Git identity to $identity_file"
}

configure_git_identity() {
  local existing_name existing_email git_name git_email identity_file

  identity_file="$HOME/$GIT_IDENTITY_FILE_RELATIVE"

  if [ -z "${DOTFILES_GIT_NAME:-}" ] && [ -z "${DOTFILES_GIT_EMAIL:-}" ]; then
    existing_name="$(read_existing_identity_file user.name)"
    existing_email="$(read_existing_identity_file user.email)"

    if [ -n "$existing_name" ] && [ -n "$existing_email" ]; then
      log_info "Git identity already configured in $identity_file"
      return
    fi
  fi

  existing_name="${DOTFILES_GIT_NAME:-$(git config --global user.name 2>/dev/null || true)}"
  existing_email="${DOTFILES_GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"

  if [ -t 0 ] && [ -t 1 ]; then
    log_step "Configuring Git identity"
    git_name="$(prompt_with_default "Git user.name" "$existing_name")"
    git_email="$(prompt_with_default "Git user.email" "$existing_email")"
  else
    git_name="$existing_name"
    git_email="$existing_email"
  fi

  if [ -z "$git_name" ] || [ -z "$git_email" ]; then
    log_warn "Skipping Git identity setup. Set DOTFILES_GIT_NAME and DOTFILES_GIT_EMAIL or rerun interactively."
    return
  fi

  write_git_identity "$git_name" "$git_email"
}
