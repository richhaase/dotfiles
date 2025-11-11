# ============================================================================
# Zellij Terminal Multiplexer
# ============================================================================

# Zellij floating run command
zrf() {
  if [ $# -eq 0 ]; then
    zellij run --floating -- zsh
  else
    zellij run --name "$*" --floating -- zsh -ic "$*"
  fi
}

# Zellij run command
zr() {
  if [ $# -eq 0 ]; then
    zellij run -- zsh
  else
    zellij run --name "$*" -- zsh -ic "$*"
  fi
}

# Zellij floating edit command
zef() {
  zellij edit --floating "$1";
}

# Zellij floating edit command
ze() {
  zellij edit "$1";
}

# Open a new Zellij tab in a target directory (or CWD) and name it after the basename
zt() {
  local target_path name

  # Use provided directory or default to current working directory
  if [ $# -ge 1 ] && [ -n "$1" ]; then
    target_path="$1"
  else
    target_path="$PWD"
  fi

  # Ensure the target path is a directory
  if [ ! -d "$target_path" ]; then
    printf 'zt: %s is not a directory\n' "$target_path" >&2
    return 1
  fi

  name="${target_path:t}" # zsh basename shorthand

  # Open new tab in the target directory
  if ! zellij action new-tab --cwd "$target_path" --name "$name" --layout agents; then
    printf 'zt: failed to open zellij tab\n' >&2
    return 1
  fi
}
