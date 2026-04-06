# shell completions configuration
fpath=("/home/dennis/.zsh/completions" $fpath)
autoload -Uz compinit
compinit

# load bash aliases
if [ -f ~/.zsh_aliases ]; then
  . ~/.zsh_aliases
fi

# amazing ssh
eval $(ssh-agent -s)
ssh-add ~/.ssh/flux >>/dev/null

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

# Noji settings
export NOJI_CONFIG_HOME="$HOME/.config"
export EDITOR="nvim"

# Zoxide
eval "$(zoxide init zsh)"

# emacs mode
bindkey -e

# starship
eval "$(starship init zsh)"

# mise
eval "$(mise activate zsh)"

# CUDA CUDA CUDA
export CUDA_VISIBLE_DEVICES=0

# anon
export OPENSPEC_TELEMETRY=0

. "$HOME/.local/share/../bin/env"
