# load bash aliases
if [ -f ~/.zsh_aliases ]; then
  . ~/.zsh_aliases
fi

# amazing ssh
eval $(ssh-agent -s)
ssh-add ~/.ssh/flux

# path variables 
if [ -d "$HOME/bin" ]; then
	PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ]; then
	PATH="$HOME/.local/bin:$PATH"
fi

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
