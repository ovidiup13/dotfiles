if [ -f "$HOME/.config/shell/env.sh" ]; then
  . "$HOME/.config/shell/env.sh"
fi

if [ -f "$HOME/.config/shell/path.sh" ]; then
  . "$HOME/.config/shell/path.sh"
fi

if [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
