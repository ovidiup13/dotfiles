export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export LANG="${LANG:-en_GB.UTF-8}"

if [ -t 1 ] && command -v tty >/dev/null 2>&1; then
  export GPG_TTY="$(tty)"
fi

export GOPATH="${GOPATH:-$HOME/go}"
export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
export GEM_HOME="${GEM_HOME:-$HOME/.gem}"
export JENV_ROOT="${JENV_ROOT:-$HOME/.jenv}"
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

case "$(uname -s)" in
  Darwin)
    export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
    ;;
  *)
    export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    ;;
esac

if [ -f "$HOME/.secrets/tokens" ]; then
  . "$HOME/.secrets/tokens"
fi

if [ -n "${SSH_CONNECTION:-}" ]; then
  export EDITOR='vim'
elif command -v nvim >/dev/null 2>&1; then
  export EDITOR='nvim'
elif command -v vim >/dev/null 2>&1; then
  export EDITOR='vim'
fi
