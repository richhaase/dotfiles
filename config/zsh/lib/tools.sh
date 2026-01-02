# ============================================================================
# Development Tools
# ============================================================================

# Tool shortcuts
alias lg="lazygit"
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias cr='code_review.py'

# Helix helpers
hxg() {
  if ! (( $+commands[hx] )); then
    echo "hxg: helix (hx) not found in PATH" >&2
    return 127
  fi
  hx --grammar fetch && hx --grammar build
}
