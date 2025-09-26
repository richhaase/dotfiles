# ============================================================================
# Core Setup
# ============================================================================

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# ============================================================================
# Environment Variables
# ============================================================================

export EDITOR=hx
export LANG=en_US.UTF-8

# Plugin directory
ZPLUGINDIR="$HOME/.config/zsh/plugins"

# ============================================================================
# PATH Configuration
# ============================================================================

export PATH="${HOME}/bin:$PATH"
export PATH="$(go env GOPATH)/bin:$PATH"
export PATH="${HOME}/.pixi/bin:$PATH"
export PATH="${HOME}/.local/bin:$PATH"

# ============================================================================
# Package Managers
# ============================================================================

# Cargo (Rust)
. "$HOME/.cargo/env"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Node Version Manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "/Users/rdh/.bun/_bun" ] && source "/Users/rdh/.bun/_bun"

# ============================================================================
# Shell Options
# ============================================================================

setopt AUTO_MENU
setopt COMPLETE_IN_WORD

# ============================================================================
# Plugin System
# ============================================================================

source ~/.plugins.zsh

plugins=(
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-autosuggestions
)

plugin-load $plugins

# ============================================================================
# Tool Initializations
# ============================================================================

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(mcfly init zsh)"

# ============================================================================
# FZF Configuration
# ============================================================================

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=header,grid --line-range :300 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -50'"

source <(fzf --zsh)


# ============================================================================
# Custom Configurations
# ============================================================================

# Load functional modules (aliases, functions, env vars by domain)
ZLIBDIR="$HOME/.config/zsh/lib"
if [[ -d "$ZLIBDIR" ]]; then
  for lib in "$ZLIBDIR"/*.sh; do
    [[ -f "$lib" ]] && source "$lib"
  done
fi

# ============================================================================
# Final Hooks
# ============================================================================

# Load direnv
eval "$(direnv hook zsh)"