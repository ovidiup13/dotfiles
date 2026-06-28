if [ -f "$HOME/.config/shell/env.sh" ]; then
  . "$HOME/.config/shell/env.sh"
fi

if [ -f "$HOME/.config/shell/path.sh" ]; then
  . "$HOME/.config/shell/path.sh"
fi

if [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi

if [ -z "${DOTFILES_LOCAL_BIN_ENV_LOADED:-}" ] && [ -r "$HOME/.local/bin/env" ]; then
  DOTFILES_LOCAL_BIN_ENV_LOADED=1
  . "$HOME/.local/bin/env"
fi
