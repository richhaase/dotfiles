# ============================================================================
# System & Process Management
# ============================================================================

# System utilities aliases
alias b="bat"
alias df='duf'
alias du="dust"
alias refresh='exec zsh'

# Fuzzy process killer
fkill() {
  (( $+commands[procs] )) || { echo "fkill: procs not installed" >&2; return 1; }
  (( $+commands[choose] )) || { echo "fkill: choose not installed" >&2; return 1; }
  local pid
  pid=$(procs | fzf | choose 0) && [[ -n "$pid" ]] && kill "$pid"
}
