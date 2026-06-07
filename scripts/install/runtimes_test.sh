#!/usr/bin/env bash

set -euo pipefail

script_path="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/runtimes.sh"
repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
env_path="$repo_root/home/.config/shell/env.sh"
path_path="$repo_root/home/.config/shell/path.sh"

for function_name in \
  install_bun \
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
