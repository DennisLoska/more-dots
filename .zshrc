# shell completions configuration
if [ -d "$HOME/.zsh/completions" ]; then
  fpath=("$HOME/.zsh/completions" $fpath)
fi
autoload -Uz compinit
compinit

# load aliases
if [ -f ~/.zsh_aliases ]; then
  . ~/.zsh_aliases
fi

# brew (macOS only, no-op on Linux)
if [ -x /opt/homebrew/bin/brew ]; then
  export HOMEBREW_NO_ANALYTICS=1
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# path variables
if [ -d "$HOME/bin" ]; then
  PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ]; then
  PATH="$HOME/.local/bin:$PATH"
fi

# tmux
if [ -n "$TMUX" ]; then
  tmux source-file ~/.tmux.conf
fi

# zsh history
setopt SHARE_HISTORY
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=100000
histignore=all

# go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# editor
export EDITOR="nvim"

# zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# emacs mode
bindkey -e

# starship
eval "$(starship init zsh)"

# mise
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# CUDA CUDA CUDA
export CUDA_VISIBLE_DEVICES=0


# load local bin env if present
if [ -f "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi

# keep it secret, keep it safe
export LINEAR_API_KEY="redacted"
