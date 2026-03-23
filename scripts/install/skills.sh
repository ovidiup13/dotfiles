#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"

. "$REPO_ROOT/scripts/lib/common.sh"

DOTFILES_SKILLS_AGENTS="${DOTFILES_SKILLS_AGENTS:-universal opencode}"

ensure_skills_cli() {
  if command_exists skills; then
    return
  fi

  log_error "skills CLI is required but was not found."
  exit 1
}

verify_skills_manifest() {
  local skills_file="$REPO_ROOT/packages/macos/skills.txt"
  local lock_file="$HOME/.agents/.skill-lock.json"
  local manifest_sources lock_sources

  if ! command_exists jq; then
    log_warn "Skipping skill manifest verification because jq is not installed."
    return
  fi

  if [ ! -f "$lock_file" ]; then
    log_warn "Skipping skill manifest verification because $lock_file was not found."
    return
  fi

  manifest_sources="$(grep -Ev '^[[:space:]]*(#|$)' "$skills_file" | sort -u)"
  lock_sources="$(jq -r '.skills | to_entries[] | .value.source' "$lock_file" | sort -u)"

  if [ "$manifest_sources" != "$lock_sources" ]; then
    log_error "packages/macos/skills.txt does not match the sources in $lock_file"
    exit 1
  fi
}

install_skills() {
  local skills_file="$REPO_ROOT/packages/macos/skills.txt"
  local source
  local -a agent_args=()
  local agent

  if [ ! -f "$skills_file" ]; then
    log_error "Skills manifest not found: $skills_file"
    exit 1
  fi

  for agent in $DOTFILES_SKILLS_AGENTS; do
    agent_args+=(--agent "$agent")
  done

  log_step "Installing agent skills"
  while IFS= read -r source; do
    if [ -z "$source" ] || [[ "$source" == \#* ]]; then
      continue
    fi

    log_info "skills add $source"
    skills add "$source" --global --skill '*' --yes "${agent_args[@]}"
  done < "$skills_file"
}

main() {
  ensure_skills_cli
  verify_skills_manifest
  install_skills
}

main "$@"
