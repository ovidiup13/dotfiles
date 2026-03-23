if [ -f "$HOME/.config/shell/env.sh" ]; then
  . "$HOME/.config/shell/env.sh"
fi

if [ -f "$HOME/.config/shell/path.sh" ]; then
  . "$HOME/.config/shell/path.sh"
fi

if [ -f "$HOME/.config/shell/aliases.sh" ]; then
  . "$HOME/.config/shell/aliases.sh"
fi

if [ -f "$HOME/.fzf.bash" ]; then
  . "$HOME/.fzf.bash"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi
