#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"

. "$REPO_ROOT/scripts/lib/common.sh"
. "$REPO_ROOT/scripts/lib/symlink.sh"

main() {
  local skills_root="$REPO_ROOT/home/.agents/skills"
  local first_skill

  first_skill="$(find "$skills_root" -name SKILL.md -type f -print -quit 2>/dev/null || true)"
  if [ -z "$first_skill" ]; then
    log_error "No vendored agent skills found in $skills_root"
    exit 1
  fi

  link_agent_skills "$REPO_ROOT"
}

main "$@"
