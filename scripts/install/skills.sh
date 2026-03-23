#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"

. "$REPO_ROOT/scripts/lib/common.sh"

DOTFILES_SKILLS_AGENTS="${DOTFILES_SKILLS_AGENTS:-universal opencode}"

parse_skills_manifest() {
  local skills_file="$REPO_ROOT/packages/macos/skills.txt"
  local entries_file="$1"
  local names_file="$2"
  local line source skill

  : > "$entries_file"
  : > "$names_file"

  if [ ! -f "$skills_file" ]; then
    log_error "Skills manifest not found: $skills_file"
    exit 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    set -- $line

    if [ "$#" -eq 0 ]; then
      continue
    fi

    if [ "$#" -ne 2 ]; then
      log_error "Each skills.txt entry must be '<source> <skill>': $line"
      exit 1
    fi

    source="$1"
    skill="$2"

    printf '%s\t%s\n' "$source" "$skill" >> "$entries_file"
    printf '%s\n' "$skill" >> "$names_file"
  done < "$skills_file"

  if [ ! -s "$entries_file" ]; then
    log_error "No skills were defined in $skills_file"
    exit 1
  fi

  sort -u "$entries_file" -o "$entries_file"
  sort -u "$names_file" -o "$names_file"
}

ensure_skills_cli() {
  if command_exists skills; then
    return
  fi

  log_error "skills CLI is required but was not found."
  exit 1
}

write_installed_entries() {
  local output_file="$1"
  local lock_file="$HOME/.agents/.skill-lock.json"

  : > "$output_file"

  if ! command_exists jq; then
    return
  fi

  if [ ! -f "$lock_file" ]; then
    return
  fi

  jq -r '.skills | to_entries[] | "\(.value.source)\t\(.key)"' "$lock_file" | sort -u > "$output_file"
}

remove_unmanaged_skills() {
  local names_file="$1"
  local tmp_dir="$2"
  local installed_names_file="$tmp_dir/installed-skills.txt"
  local extra_names_file="$tmp_dir/extra-skills.txt"
  local -a remove_args=()
  local skill

  if ! command_exists jq; then
    log_warn "Skipping skill cleanup because jq is not installed."
    return
  fi

  skills list --global --json | jq -r '.[].name' | sort -u > "$installed_names_file"
  comm -23 "$installed_names_file" "$names_file" > "$extra_names_file"

  if [ ! -s "$extra_names_file" ]; then
    return
  fi

  while IFS= read -r skill; do
    [ -n "$skill" ] && remove_args+=("$skill")
  done < "$extra_names_file"

  if [ "${#remove_args[@]}" -eq 0 ]; then
    return
  fi

  log_step "Removing unmanaged skills"
  skills remove "${remove_args[@]}" --global --yes
}

verify_installed_skills() {
  local lock_file="$HOME/.agents/.skill-lock.json"
  local entries_file="$1"
  local tmp_dir="$2"
  local installed_entries_file="$tmp_dir/installed-entries.txt"

  if ! command_exists jq; then
    log_warn "Skipping skill manifest verification because jq is not installed."
    return
  fi

  if [ ! -f "$lock_file" ]; then
    log_warn "Skipping skill manifest verification because $lock_file was not found."
    return
  fi

  write_installed_entries "$installed_entries_file"

  if ! cmp -s "$entries_file" "$installed_entries_file"; then
    log_error "packages/macos/skills.txt does not match the installed skills in $lock_file"
    exit 1
  fi
}

install_skills() {
  local entries_file="$1"
  local tmp_dir="$2"
  local installed_entries_file="$tmp_dir/installed-entries.txt"
  local pending_entries_file="$tmp_dir/pending-entries.txt"
  local -a agent_args=()
  local agent
  local entry source skill

  for agent in $DOTFILES_SKILLS_AGENTS; do
    agent_args+=(--agent "$agent")
  done

  write_installed_entries "$installed_entries_file"

  if [ -s "$installed_entries_file" ]; then
    comm -23 "$entries_file" "$installed_entries_file" > "$pending_entries_file"
  else
    cp "$entries_file" "$pending_entries_file"
  fi

  if [ ! -s "$pending_entries_file" ]; then
    log_info "Agent skills already match packages/macos/skills.txt"
    return
  fi

  log_step "Installing agent skills"
  while IFS= read -r entry <&3 || [ -n "$entry" ]; do
    [ -z "$entry" ] && continue
    source="${entry%%$'\t'*}"
    skill="${entry#*$'\t'}"

    log_info "skills add $source --skill $skill"
    skills add "$source" --global --skill "$skill" --yes "${agent_args[@]}"
  done 3< "$pending_entries_file"
}

main() {
  local tmp_dir entries_file names_file

  ensure_skills_cli

  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  entries_file="$tmp_dir/skills-entries.txt"
  names_file="$tmp_dir/skill-names.txt"

  parse_skills_manifest "$entries_file" "$names_file"
  install_skills "$entries_file" "$tmp_dir"
  remove_unmanaged_skills "$names_file" "$tmp_dir"
  verify_installed_skills "$entries_file" "$tmp_dir"
}

main "$@"
