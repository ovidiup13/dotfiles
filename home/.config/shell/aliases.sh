if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
fi

if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  alias bat='batcat'
fi

if command -v btop >/dev/null 2>&1; then
  alias top='btop'
fi

if command -v kubectl >/dev/null 2>&1; then
  alias k='kubectl'
fi

if command -v kubectx >/dev/null 2>&1; then
  alias kx='kubectx'
fi

if command -v kubens >/dev/null 2>&1; then
  alias kns='kubens'
fi

if command -v prettyping >/dev/null 2>&1; then
  alias ping='prettyping --nolegend'
fi

if command -v code >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
  alias preview="fzf --preview 'bat --color=always {}' --bind='ctrl-o:execute(code {})+abort'"
fi

if command -v ncdu >/dev/null 2>&1; then
  alias ncdu='ncdu --color dark -rr -x --exclude .git'
fi

if command -v nnn >/dev/null 2>&1; then
  alias n='nnn'
fi

alias refresh='exec "$SHELL" -l'
