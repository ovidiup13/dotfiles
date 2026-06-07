#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

test_1password_signin_before_environment_read() {
  local tmp_dir
  local bin_dir
  local op_log
  local secrets_file

  tmp_dir="$(mktemp -d)"
  bin_dir="$tmp_dir/bin"
  op_log="$tmp_dir/op.log"
  secrets_file="$tmp_dir/home/.secrets/tokens"

  mkdir -p "$bin_dir" "$tmp_dir/home"
  cat > "$bin_dir/op" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  whoami)
    exit 1
    ;;
  signin)
    printf 'signin\n' >> "$OP_TEST_LOG"
    printf 'export OP_SESSION_test=token\n'
    ;;
  environment)
    if [ "${2:-}" != "read" ] || [ "${3:-}" != "env-id" ]; then
      exit 2
    fi

    if [ "${OP_SESSION_test:-}" != "token" ]; then
      exit 3
    fi

    printf 'TEST_SECRET=hello world\n'
    ;;
  *)
    exit 4
    ;;
esac
EOF
  chmod +x "$bin_dir/op"

  (
    export HOME="$tmp_dir/home"
    export OP_TEST_LOG="$op_log"
    export PATH="$bin_dir:$PATH"

    . "$REPO_ROOT/scripts/lib/common.sh"
    . "$REPO_ROOT/scripts/install/secrets.sh"

    sync_1password_secrets "env-id" >/dev/null
  )

  if ! grep -q '^signin$' "$op_log"; then
    printf 'expected op signin to be invoked\n' >&2
    return 1
  fi

  if ! grep -q '^TEST_SECRET="hello world"$' "$secrets_file"; then
    printf 'expected secrets file to quote environment values\n' >&2
    return 1
  fi

  rm -rf "$tmp_dir"
}

test_1password_signin_before_environment_read
