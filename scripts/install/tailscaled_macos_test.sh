#!/usr/bin/env bash

set -euo pipefail

script_path="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/tailscaled_macos.sh"

if [ ! -f "$script_path" ]; then
  printf 'missing standalone macOS tailscaled installer: %s\n' "$script_path" >&2
  exit 1
fi

for required in \
  'Darwin' \
  'SSH_CONNECTION' \
  'tailscale ip' \
  'brew upgrade goenv' \
  'goenv install -s latest' \
  'go install tailscale.com/cmd/tailscale{,d}@main' \
  'uninstall-system-daemon' \
  'install-system-daemon' \
  'tailscale status'
do
  if ! grep -q "$required" "$script_path"; then
    printf 'missing tailscaled macOS installer behavior: %s\n' "$required" >&2
    exit 1
  fi
done
