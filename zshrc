# .zshrc
# 
ZPLUGINDIR="$HOME/.config/zsh/plugins"

source ~/.plugins.zsh

plugins=(
  sindresorhus/pure
  
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-autosuggestions
)

plugin-load $plugins


# Variables
export EDITOR=nvim

# Aliases
alias ddu="du -d 1 -h | sort -h"
## tmux
alias txs="tmuxinator start"
alias txl="tmuxinator list"

# neovim
which nvim &>/dev/null && alias vim=nvim && alias vi=nvim

# atuin
eval "$(atuin init zsh)"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
