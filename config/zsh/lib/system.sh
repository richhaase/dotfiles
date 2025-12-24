# ============================================================================
# System & Process Management
# ============================================================================

# System utilities aliases
alias b="bat"
alias df='duf'
alias du="dust"
alias myip='curl ifconfig.me'
alias ports='netstat -tuln'
alias refresh='exec zsh'
alias stats="tokei"
alias weather='curl wttr.in'

# Fuzzy process killer
fkill() {
  (( $+commands[procs] )) || { echo "fkill: procs not installed" >&2; return 1; }
  local pid
  pid=$(procs | fzf | choose 0) && [[ -n "$pid" ]] && kill "$pid"
}
