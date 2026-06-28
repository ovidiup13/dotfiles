#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

test_skills_sync_does_not_call_skills_cli() {
  local tmp_dir
  local bin_dir
  local skills_log
  local status

  tmp_dir="$(mktemp -d)"
  bin_dir="$tmp_dir/bin"
  skills_log="$tmp_dir/skills.log"

  mkdir -p "$bin_dir" "$tmp_dir/home"
  cat > "$bin_dir/skills" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$SKILLS_TEST_LOG"
exit 99
EOF
  chmod +x "$bin_dir/skills"

  set +e
  (
    export HOME="$tmp_dir/home"
    export SKILLS_TEST_LOG="$skills_log"
    export PATH="$bin_dir:$PATH"

    "$REPO_ROOT/scripts/install/skills.sh" >/dev/null
  )
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    printf 'expected vendored skills sync to succeed without skills CLI\n' >&2
    return 1
  fi

  if [ -f "$skills_log" ]; then
    printf 'expected vendored skills sync not to call skills CLI\n' >&2
    return 1
  fi

  rm -rf "$tmp_dir"
}

test_link_home_tree_links_skills_subtree() {
  local tmp_dir
  local repo_root
  local target

  tmp_dir="$(mktemp -d)"
  repo_root="$tmp_dir/repo"
  target="$tmp_dir/home/.agents/skills"

  mkdir -p "$repo_root/home/.agents/skills/example" "$tmp_dir/home"
  printf '# Example\n' > "$repo_root/home/.agents/skills/example/SKILL.md"

  (
    export HOME="$tmp_dir/home"

    . "$REPO_ROOT/scripts/lib/common.sh"
    . "$REPO_ROOT/scripts/lib/symlink.sh"

    link_home_tree "$repo_root" >/dev/null
  )

  if [ ! -L "$target" ]; then
    printf 'expected skills subtree to be symlinked as one directory\n' >&2
    return 1
  fi

  if [ "$(readlink "$target")" != "$repo_root/home/.agents/skills" ]; then
    printf 'expected skills subtree symlink to point at repo home tree\n' >&2
    return 1
  fi

  rm -rf "$tmp_dir"
}

test_skills_sync_does_not_call_skills_cli
test_link_home_tree_links_skills_subtree
