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

# Use zsh-native path array with deduplication
typeset -U path PATH
path=("${HOME}/.bin" "${HOME}/.pixi/bin" "${HOME}/.local/bin" $path)
(( $+commands[go] )) && path+=("$(go env GOPATH 2>/dev/null)/bin")

# ============================================================================
# Package Managers
# ============================================================================

# Cargo (Rust)
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
[[ -d "$PNPM_HOME" ]] && path+=("$PNPM_HOME")

# Bun
export BUN_INSTALL="$HOME/.bun"
path+=("$BUN_INSTALL/bin")
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# ============================================================================
# Shell Options
# ============================================================================

setopt AUTO_MENU
setopt COMPLETE_IN_WORD

# ============================================================================
# History
# ============================================================================

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY       # Append to the history file, don't overwrite
setopt INC_APPEND_HISTORY   # Write after each command finishes
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE    # Commands starting with a space are not saved
setopt HIST_VERIFY          # Expand history but do not execute immediately

# ============================================================================
# Plugin System
# ============================================================================

[ -r "$HOME/.config/zsh/lib/plugin_loader.sh" ] && source "$HOME/.config/zsh/lib/plugin_loader.sh"

plugins=(
  romkatv/zsh-defer
  zsh-users/zsh-completions
  zsh-users/zsh-autosuggestions
  Aloxaf/fzf-tab
)

plugin-load $plugins

# ============================================================================
# Completions
# ============================================================================

# Add Homebrew completions to fpath if available
if [[ -n "${HOMEBREW_PREFIX:-}" && -d "${HOMEBREW_PREFIX}/share/zsh/site-functions" ]]; then
  fpath+=("${HOMEBREW_PREFIX}/share/zsh/site-functions")
fi

autoload -Uz compinit
zmodload -i zsh/complist 2>/dev/null
compinit -C

# Completion UI tweaks
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=** r:|=**'

# fzf-tab configuration (previews + group switching)
zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -lah --color=always --icons=always "$realpath" 2>/dev/null | head -200'
zstyle ':fzf-tab:complete:*:argument-rest' fzf-preview '[ -d "$realpath" ] && eza --tree --color=always --icons=always "$realpath" | head -200 || (bat --color=always --style=header,grid --line-range :200 "$realpath" 2>/dev/null || file --brief "$realpath")'

# ============================================================================
# Tool Initializations
# ============================================================================

(( $+commands[starship] )) && eval "$(starship init zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# ============================================================================
# FZF Configuration
# ============================================================================

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=header,grid --line-range :300 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -50'"

(( $+commands[fzf] )) && source <(fzf --zsh)

# Initialize Atuin AFTER fzf so Ctrl+R uses Atuin instead of fzf
(( $+commands[atuin] )) && eval "$(atuin init zsh)"


# ============================================================================
# Custom Configurations
# ============================================================================

# Load functional modules explicitly (clear order, no wildcard loops)
[ -r "$HOME/.config/zsh/lib/system.sh" ] && source "$HOME/.config/zsh/lib/system.sh"
[ -r "$HOME/.config/zsh/lib/files.sh" ] && source "$HOME/.config/zsh/lib/files.sh"
[ -r "$HOME/.config/zsh/lib/tools.sh" ] && source "$HOME/.config/zsh/lib/tools.sh"
[ -r "$HOME/.config/zsh/lib/git.sh" ] && source "$HOME/.config/zsh/lib/git.sh"
[ -r "$HOME/.config/zsh/lib/zellij.sh" ] && source "$HOME/.config/zsh/lib/zellij.sh"
[ -r "$HOME/.config/zsh/lib/aws.sh" ] && source "$HOME/.config/zsh/lib/aws.sh"

# ============================================================================
# Final Hooks
# ============================================================================

# Load direnv
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

# Load syntax highlighting last, per plugin guidance
plugin-load zsh-users/zsh-syntax-highlighting
