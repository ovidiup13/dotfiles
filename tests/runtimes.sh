#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

test_bun_upgrade_when_already_installed() {
  local tmp_dir
  local bin_dir
  local bun_log

  tmp_dir="$(mktemp -d)"
  bin_dir="$tmp_dir/bin"
  bun_log="$tmp_dir/bun.log"

  mkdir -p "$bin_dir" "$tmp_dir/home"
  cat > "$bin_dir/bun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$BUN_TEST_LOG"
EOF
  chmod +x "$bin_dir/bun"

  (
    export HOME="$tmp_dir/home"
    export BUN_TEST_LOG="$bun_log"
    export PATH="$bin_dir:$PATH"

    . "$REPO_ROOT/scripts/lib/common.sh"
    . "$REPO_ROOT/scripts/install/runtimes.sh"

    install_bun >/dev/null
  )

  if ! grep -q '^upgrade$' "$bun_log"; then
    printf 'expected install_bun to run bun upgrade when bun already exists\n' >&2
    return 1
  fi

  rm -rf "$tmp_dir"
}

test_macos_runtimes_do_not_run_vp_env_subcommands() {
  local tmp_dir
  local bin_dir
  local vp_log
  local status

  tmp_dir="$(mktemp -d)"
  bin_dir="$tmp_dir/bin"
  vp_log="$tmp_dir/vp.log"

  mkdir -p "$bin_dir" "$tmp_dir/home"
  cat > "$bin_dir/vp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$VP_TEST_LOG"

case "$*" in
  env\ setup*|env\ on|env\ default*|env\ install*)
  exit 42
  ;;
esac
EOF
  chmod +x "$bin_dir/vp"

  set +e
  (
    export HOME="$tmp_dir/home"
    export VP_TEST_LOG="$vp_log"
    export PATH="$bin_dir:$PATH"

    . "$REPO_ROOT/scripts/lib/common.sh"
    . "$REPO_ROOT/scripts/install/runtimes.sh"

    install_uv() { :; }
    install_basic_memory() { :; }
    install_rustup() { :; }
    install_goenv_latest() { :; }

    install_macos_runtimes >/dev/null
  )
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    printf 'expected install_macos_runtimes to avoid vp env subcommands\n' >&2
    return 1
  fi

  if [ -f "$vp_log" ]; then
    printf 'expected install_macos_runtimes not to call vp env subcommands\n' >&2
    return 1
  fi

  rm -rf "$tmp_dir"
}

test_vp_installer_disables_node_manager_prompt() {
  local tmp_dir
  local bin_dir

  tmp_dir="$(mktemp -d)"
  bin_dir="$tmp_dir/bin"

  mkdir -p "$bin_dir" "$tmp_dir/home"
  cat > "$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if [ "${VP_NODE_MANAGER:-}" != "yes" ]; then
  exit 43
fi

mkdir -p "$VP_HOME/bin"
cat > "$VP_HOME/bin/vp" <<'VP'
#!/usr/bin/env bash
exit 0
VP
chmod +x "$VP_HOME/bin/vp"
cat > "$VP_HOME/env" <<ENV
PATH="$VP_HOME/bin:\$PATH"
export PATH
ENV
SCRIPT
EOF
  chmod +x "$bin_dir/curl"

  (
    export HOME="$tmp_dir/home"
    export PATH="$bin_dir:/usr/bin:/bin:/usr/sbin:/sbin"

    . "$REPO_ROOT/scripts/lib/common.sh"
    . "$REPO_ROOT/scripts/install/runtimes.sh"

    install_vp_cli >/dev/null
  )

  rm -rf "$tmp_dir"
}

test_load_cargo_env_honors_cargo_home() {
  local tmp_dir

  tmp_dir="$(mktemp -d)"

  mkdir -p "$tmp_dir/cargo"
  cat > "$tmp_dir/cargo/env" <<'EOF'
RUNTIMES_TEST_CARGO_ENV=loaded
export RUNTIMES_TEST_CARGO_ENV
EOF

  (
    export HOME="$tmp_dir/home"
    export CARGO_HOME="$tmp_dir/cargo"
    unset RUNTIMES_TEST_CARGO_ENV

    . "$REPO_ROOT/scripts/lib/common.sh"
    . "$REPO_ROOT/scripts/install/runtimes.sh"

    load_cargo_env

    if [ "${RUNTIMES_TEST_CARGO_ENV:-}" != "loaded" ]; then
      printf 'expected load_cargo_env to source CARGO_HOME/env\n' >&2
      return 1
    fi
  )

  rm -rf "$tmp_dir"
}

test_bun_upgrade_when_already_installed
test_macos_runtimes_do_not_run_vp_env_subcommands
test_vp_installer_disables_node_manager_prompt
test_load_cargo_env_honors_cargo_home
