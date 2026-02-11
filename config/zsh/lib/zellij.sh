# ============================================================================
# Zellij Terminal Multiplexer
# ============================================================================

# Zellij floating run command
zrf() {
  if [ $# -eq 0 ]; then
    zellij run --floating -x 10% -y 10% --width 80% --height 80% -- zsh
  else
    zellij run --name "$*" --floating -x 10% -y 10% --width 80% --height 80% -- zsh -ic "$*"
  fi
}

alias zlg='zrf lg'
alias zbt='zrf btop'
