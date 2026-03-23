if ! command -v fzf >/dev/null 2>&1; then
  return 0
fi

if output="$(fzf --zsh 2>/dev/null)" && [ -n "$output" ]; then
  eval "$output"
  unset output
  return 0
fi

brew_prefix=''

if command -v brew >/dev/null 2>&1; then
  brew_prefix="$(brew --prefix 2>/dev/null)"
fi

for file in \
  /usr/share/doc/fzf/examples/completion.zsh \
  /usr/share/doc/fzf/examples/key-bindings.zsh \
  "$brew_prefix/opt/fzf/shell/completion.zsh" \
  "$brew_prefix/opt/fzf/shell/key-bindings.zsh"
do
  if [ -n "$file" ] && [ -f "$file" ]; then
    . "$file"
  fi
done
