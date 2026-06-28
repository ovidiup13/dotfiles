if [ -f "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi

if [ -z "${DOTFILES_LOCAL_BIN_ENV_LOADED:-}" ] && [ -r "$HOME/.local/bin/env" ]; then
  DOTFILES_LOCAL_BIN_ENV_LOADED=1
  . "$HOME/.local/bin/env"
fi
