path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

path_append() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="${PATH:+$PATH:}$1" ;;
  esac
}

for dir in \
  "$HOME/.local/bin" \
  "$HOME/bin" \
  "$HOME/.cargo/bin" \
  "$GEM_HOME/bin" \
  "$GOENV_ROOT/bin" \
  "$GOPATH/bin" \
  "$JENV_ROOT/bin" \
  "$PYENV_ROOT/bin" \
  "$PNPM_HOME" \
  "$BUN_INSTALL/bin"
do
  if [ -d "$dir" ]; then
    path_prepend "$dir"
  fi
done

if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
  for dir in "$BREW_PREFIX/bin" "$BREW_PREFIX/sbin"; do
    if [ -d "$dir" ]; then
      path_prepend "$dir"
    fi
  done
fi

export PATH
