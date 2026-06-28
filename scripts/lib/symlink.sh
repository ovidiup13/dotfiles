#!/usr/bin/env bash

set -euo pipefail

link_managed_path() {
  local source="$1"
  local target="$2"
  local backup_root="$3"
  local rel="$4"
  local target_dir current_target

  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"

  if [ -L "$target" ]; then
    current_target="$(readlink "$target")"
    if [ "$current_target" = "$source" ]; then
      log_info "Linked $target"
      return
    fi
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$backup_root/$(dirname "$rel")"
    mv "$target" "$backup_root/$rel"
    log_warn "Backed up existing $target to $backup_root/$rel"
  fi

  ln -s "$source" "$target"
  log_success "Linked $target"
}

link_agent_skills() {
  local repo_root="$1"
  local source="$repo_root/home/.agents/skills"
  local target="$HOME/.agents/skills"
  local backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d%H%M%S)"

  if [ ! -d "$source" ]; then
    log_error "Managed agent skills directory not found: $source"
    exit 1
  fi

  link_managed_path "$source" "$target" "$backup_root" ".agents/skills"
}

link_home_tree() {
  local repo_root="$1"
  local source_root="$repo_root/home"
  local skills_source="$source_root/.agents/skills"
  local backup_root

  if [ ! -d "$source_root" ]; then
    log_error "Managed home directory not found: $source_root"
    exit 1
  fi

  backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d%H%M%S)"

  if [ -d "$skills_source" ]; then
    link_managed_path "$skills_source" "$HOME/.agents/skills" "$backup_root" ".agents/skills"
  fi

  find "$source_root" \( -type f -o -type l \) | while IFS= read -r source; do
    local rel target

    case "$source" in
      "$skills_source"/*)
        continue
        ;;
    esac

    rel="${source#"$source_root"/}"
    target="$HOME/$rel"
    link_managed_path "$source" "$target" "$backup_root" "$rel"
  done
}
