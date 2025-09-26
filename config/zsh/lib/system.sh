# ============================================================================
# System & Process Management
# ============================================================================

# System utilities aliases
alias b="bat"
alias df='duf'
alias du="dust"
alias myip='curl ifconfig.me'
alias netcheck='procs | choose 0,10 | sort -nr'
alias ports='netstat -tuln'
alias refresh='exec zsh'
alias stats="tokei"
alias weather='curl wttr.in'

# Fuzzy process killer
fkill() {
  procs | fzf | choose 0 | xargs kill
}
