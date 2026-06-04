# ============================================================================
# Aliases & Helpers
# ============================================================================

# System
alias b="bat"
alias refresh='exec zsh'

# Files
alias ll="eza -la --icons --group-directories-first"

# Tools
alias lg="lazygit"
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Git
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
alias gwip='git add -A && git commit -m "WIP"'
alias gundo='git reset HEAD~1 --mixed'
alias gconflicts='git diff --name-only --diff-filter=U'
alias gsup='git submodule update'
alias grv='git remote --verbose'
