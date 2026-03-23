if ! command -v fzf >/dev/null 2>&1; then
  return 0
fi

if output="$(fzf --bash 2>/dev/null)" && [ -n "$output" ]; then
  eval "$output"
  unset output
  return 0
fi

brew_prefix=''

if command -v brew >/dev/null 2>&1; then
  brew_prefix="$(brew --prefix 2>/dev/null)"
fi

for file in \
  /usr/share/doc/fzf/examples/completion.bash \
  /usr/share/doc/fzf/examples/key-bindings.bash \
  "$brew_prefix/opt/fzf/shell/completion.bash" \
  "$brew_prefix/opt/fzf/shell/key-bindings.bash"
do
  if [ -n "$file" ] && [ -f "$file" ]; then
    . "$file"
  fi
done
