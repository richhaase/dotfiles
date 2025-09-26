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
# System Aliases
# ============================================================================

alias b="bat"
alias df='duf'
alias du="dust"
alias ll="eza -la --icons --group-directories-first"
alias myip='curl ifconfig.me'
alias netcheck='procs | choose 0,10 | sort -nr'
alias ports='netstat -tuln'
alias refresh="source ~/.zshrc"
alias stats="tokei"
alias weather='curl wttr.in'

# ============================================================================
# Tool Shortcuts
# ============================================================================

alias lg="lazygit"
alias nv='nvim'
alias dirs='fd --type d | fzf --preview "eza --tree --color=always {}"'
alias files='fd --type f | fzf --preview "bat --color=always {}"'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# ============================================================================
# Git Aliases
# ============================================================================

alias branches='git branch --sort=-committerdate | head -10'
alias gst='git status'
alias gco='git checkout'
alias gcob='git checkout -b'
alias glog='git log --date=short --graph --format="%C(bold cyan)%h%C(reset) %C(red)%ad%C(auto)%d %C(reset)%s %C(cyan)(%an)"'
alias gp='git push'
alias gl='git pull'
alias ga='git add'
alias gc='git commit'
alias gca='git commit --amend --no-edit'
alias gclean='git branch --merged | grep -v "\*\|main\|trunk" | xargs git branch -d'
alias gfix='git add -A && git commit --fixup=HEAD'
alias gwip='git add -A && git commit -m "WIP"'

# Git worktree aliases
alias lswt='git worktree list'

# ============================================================================
# Functions
# ============================================================================

# File manager integration - open yazi and cd to selected directory
y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# AWS profile selector
awsp() {
  export AWS_PROFILE=$(aws configure list-profiles | fzf)
}

# Fuzzy process killer
fkill() {
  procs | fzf | choose 0 | xargs kill
}

# Zellij floating commands
zrf() {
  zellij run --name "$*" --floating -- zsh -ic "$*";
}

zef() {
  zellij edit --floating "$1";
}

# Git worktree management - create worktree
mkwt() {
  if [ "$#" -ne 2 ]; then
    printf 'Usage: mkwt <branch> <worktree-path>\n' >&2
    return 1
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'mkwt: not inside a git repository\n' >&2
    return 1
  fi

  local branch="$1"
  local wt_path="$2"
  local force_flag=()

  if [ -e "$wt_path" ] && [ ! -d "$wt_path" ]; then
    printf 'mkwt: %s exists and is not a directory\n' "$wt_path" >&2
    return 1
  fi
  if [ -d "$wt_path" ] && [ -n "$(ls -A "$wt_path" 2>/dev/null)" ]; then
    printf 'mkwt: %s exists and is not empty\n' "$wt_path" >&2
    return 1
  fi

  mkdir -p -- "$(dirname "$wt_path")" || return 1

  if git worktree list --porcelain | grep -Fqx "branch $branch"; then
    force_flag=(--force)
  fi

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "${force_flag[@]}" "$wt_path" "$branch"
    return $?
  fi

  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    git fetch origin "$branch" || return $?
    git branch --track "$branch" "origin/$branch" || return $?
    git worktree add "${force_flag[@]}" "$wt_path" "$branch"
    return $?
  fi

  git worktree add "${force_flag[@]}" -b "$branch" "$wt_path"
}

# Git worktree management - remove worktree
rmwt() {
  local opt force_flag=() wt_path wt_abs
  OPTIND=1
  while getopts ":f" opt; do
    case "$opt" in
      f) force_flag=(--force) ;;
      \?) printf 'rmwt: invalid option -- %s\n' "$OPTARG" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND-1))

  if [ "$#" -ne 1 ]; then
    printf 'Usage: rmwt [-f] <worktree-path>\n' >&2
    return 1
  fi
  wt_path="$1"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'rmwt: not inside a git repository\n' >&2
    return 1
  fi

  if [ -d "$wt_path" ]; then
    wt_abs="$(cd "$wt_path" && pwd)"
  else
    wt_abs="$(cd "$(dirname "$wt_path")" 2>/dev/null && pwd 2>/dev/null)/$(basename "$wt_path")"
  fi

  if ! git worktree list --porcelain | grep -Fqx "worktree $wt_abs"; then
    printf 'rmwt: %s is not a registered worktree\n' "$wt_path" >&2
    return 1
  fi

  git worktree remove "${force_flag[@]}" "$wt_path"
}

# ============================================================================
# Final Hooks
# ============================================================================

# Load direnv
eval "$(direnv hook zsh)"