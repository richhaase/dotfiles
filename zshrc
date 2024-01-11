### OMZ - start ###
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="daveverwer"
zstyle ':omz:update' mode reminder  # just remind me to update when it's time
zstyle ':omz:update' frequency 13

plugins=(git tmux tmuxinator)

source $ZSH/oh-my-zsh.sh
### OMZ - end ###


# Variables
export EDITOR=nvim

# Aliases
alias ddu="du -d 1 -h | sort -h"
alias psg="tmuxinator start paragon"
alias nv=nvim

# neovim
which nvim &>/dev/null && alias vim=nvim

# pyenv
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# atuin
eval "$(atuin init zsh)"