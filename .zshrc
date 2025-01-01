# load bash aliases
if [ -f ~/.zsh_aliases ]; then
  . ~/.zsh_aliases
fi

# brew
export HOMEBREW_NO_ANALYTICS=1
eval "$(/opt/homebrew/bin/brew shellenv)"

# asdf
source $HOME/.asdf/asdf.sh

# spaceship
SPACESHIP_PROMPT_PREFIXES_SHOW="false"
source "/opt/homebrew/opt/spaceship/spaceship.zsh"
