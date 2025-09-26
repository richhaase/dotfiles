# ============================================================================
# Zellij Terminal Multiplexer
# ============================================================================

# Zellij floating run command
zr() {
  zellij run --name "$*" --floating -- zsh -ic "$*";
}

# Zellij floating run command
zp() {
  zellij run --name "$*" -- zsh -ic "$*";
}

# Zellij floating edit command
ze() {
  zellij edit --floating "$1";
}
