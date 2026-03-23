if [ -f "$HOME/.config/shell/env.sh" ]; then
  . "$HOME/.config/shell/env.sh"
fi

if [ -f "$HOME/.config/shell/path.sh" ]; then
  . "$HOME/.config/shell/path.sh"
fi

if [ -f "$HOME/.config/shell/aliases.sh" ]; then
  . "$HOME/.config/shell/aliases.sh"
fi

case "$(uname -s)" in
  Darwin)
    if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
      export ZSH="$HOME/.oh-my-zsh"
      export ZSH_THEME=""
      export DISABLE_AUTO_UPDATE=true
      export DISABLE_UPDATE_PROMPT=true
      plugins=(git direnv z vscode evalcache zsh-autosuggestions zsh-syntax-highlighting)
      . "$ZSH/oh-my-zsh.sh"
    else
      autoload -Uz compinit
      compinit
    fi
    ;;
  *)
    autoload -Uz compinit
    compinit
    ;;
esac

setopt autocd
setopt interactivecomments
setopt no_beep

if [ -f "$HOME/.fzf.zsh" ]; then
  . "$HOME/.fzf.zsh"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
  alias nvm='fnm'
fi

if command -v goenv >/dev/null 2>&1; then
  eval "$(goenv init - zsh)"
fi

if command -v jenv >/dev/null 2>&1; then
  eval "$(jenv init -)"
fi

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if [ -r "$HOME/.bun/_bun" ]; then
  . "$HOME/.bun/_bun"
fi

if [ "$(uname -s)" != "Darwin" ]; then
  for file in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  do
    if [ -f "$file" ]; then
      . "$file"
      break
    fi
  done

  for file in \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  do
    if [ -f "$file" ]; then
      . "$file"
      break
    fi
  done
fi
