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

BREW_BIN=''

if command -v brew >/dev/null 2>&1; then
  BREW_BIN="$(command -v brew)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  BREW_BIN=/home/linuxbrew/.linuxbrew/bin/brew
elif [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN=/usr/local/bin/brew
fi

if [ -n "$BREW_BIN" ]; then
  BREW_PREFIX="$($BREW_BIN --prefix)"
  for dir in "$BREW_PREFIX/bin" "$BREW_PREFIX/sbin"; do
    if [ -d "$dir" ]; then
      path_prepend "$dir"
    fi
  done
fi

export PATH
