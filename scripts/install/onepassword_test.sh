#!/usr/bin/env bash

set -euo pipefail

script_path="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/onepassword.sh"
required_fingerprint="3FEF9748469ADBE15DA7CA80AC2D62742012EA22"

if ! grep -q "$required_fingerprint" "$script_path"; then
  printf 'missing required 1Password signing key fingerprint validation\n' >&2
  exit 1
fi

if ! grep -q 'gpg --show-keys' "$script_path"; then
  printf 'missing installed keyring inspection before reuse\n' >&2
  exit 1
fi
