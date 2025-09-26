# ============================================================================
# Zellij Terminal Multiplexer
# ============================================================================

# Zellij floating run command
zrf() {
  zellij run --name "$*" --floating -- zsh -ic "$*";
}

# Zellij floating edit command
zef() {
  zellij edit --floating "$1";
}