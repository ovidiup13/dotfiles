#!/usr/bin/env bash

set -euo pipefail

link_home_tree() {
  local repo_root="$1"
  local source_root="$repo_root/home"
  local backup_root

  if [ ! -d "$source_root" ]; then
    log_error "Managed home directory not found: $source_root"
    exit 1
  fi

  backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d%H%M%S)"

  find "$source_root" \( -type f -o -type l \) | while IFS= read -r source; do
    local rel target target_dir current_target

    rel="${source#"$source_root"/}"
    target="$HOME/$rel"
    target_dir="$(dirname "$target")"

    mkdir -p "$target_dir"

    if [ -L "$target" ]; then
      current_target="$(readlink "$target")"
      if [ "$current_target" = "$source" ]; then
        log_info "Linked $target"
        continue
      fi
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
      mkdir -p "$backup_root/$(dirname "$rel")"
      mv "$target" "$backup_root/$rel"
      log_warn "Backed up existing $target to $backup_root/$rel"
    fi

    ln -s "$source" "$target"
    log_success "Linked $target"
  done
}
