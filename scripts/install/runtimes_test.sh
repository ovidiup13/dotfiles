#!/usr/bin/env bash

set -euo pipefail

script_path="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/runtimes.sh"
repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
env_path="$repo_root/home/.config/shell/env.sh"
path_path="$repo_root/home/.config/shell/path.sh"

for function_name in \
  install_bun \
  install_rustup \
  install_volta \
  install_node_lts_with_volta \
  install_opencode
do
  if ! grep -q "^${function_name}()" "$script_path"; then
    printf 'missing runtime installer function: %s\n' "$function_name" >&2
    exit 1
  fi
done

if ! grep -q 'VOLTA_HOME' "$env_path"; then
  printf 'missing VOLTA_HOME shell environment setup\n' >&2
  exit 1
fi

if awk '/^load_bun_env\(\)/,/^}/ { print }' "$script_path" | grep -q '\[ -d "\$BUN_INSTALL/bin" \]'; then
  printf 'Bun PATH setup must not depend on the bin directory existing first\n' >&2
  exit 1
fi

if ! awk '/^load_bun_env\(\)/,/^}/ { print }' "$script_path" | grep -q 'PATH="\$BUN_INSTALL/bin:\$PATH"'; then
  printf 'missing unconditional Bun PATH setup\n' >&2
  exit 1
fi

if ! awk '/^install_vp_cli\(\)/,/^}/ { print }' "$script_path" | grep -q 'HOME="\$vp_install_home" VP_HOME="\$vp_install_dir" VP_NODE_MANAGER=yes bash'; then
  printf 'Vite+ installer must run with an isolated HOME and explicit VP_HOME\n' >&2
  exit 1
fi

for path_entry in \
  '\$VOLTA_HOME/bin' \
  '\$HOME/.opencode/bin'
do
  if ! grep -q "$path_entry" "$path_path"; then
    printf 'missing shell PATH entry: %s\n' "$path_entry" >&2
    exit 1
  fi
done

for ubuntu_step in \
  install_rustup \
  install_bun \
  install_volta \
  install_node_lts_with_volta \
  install_opencode
do
  if ! awk '/^install_ubuntu_runtimes\(\)/,/^}/ { print }' "$script_path" | grep -q "  ${ubuntu_step}$"; then
    printf 'missing Ubuntu runtime step: %s\n' "$ubuntu_step" >&2
    exit 1
  fi
done

if ! awk '/^install_macos_runtimes\(\)/,/^}/ { print }' "$script_path" | grep -q '  install_rustup$'; then
  printf 'missing macOS runtime step: install_rustup\n' >&2
  exit 1
fi
