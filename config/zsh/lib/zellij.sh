# ============================================================================
# Zellij Terminal Multiplexer
# ============================================================================

alias zj='zellij'
alias zjw='zellij -l welcome'

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
  zellij edit --floating -x 10% -y 10% --width 80% --height 80% "$1";
}

# Zellij floating edit command
ze() {
  zellij edit "$1";
}

# Open a new Zellij tab in a target directory (or CWD) with optional layout
# Usage: zt [directory] [layout]
zt() {
  local target_path name layout

  # Use provided directory or default to current working directory
  if [ $# -ge 1 ] && [ -n "$1" ]; then
    target_path="$1"
  else
    target_path="$PWD"
  fi

  # Optional layout argument
  layout="$2"

  # Ensure the target path is a directory
  if [ ! -d "$target_path" ]; then
    printf 'zt: %s is not a directory\n' "$target_path" >&2
    return 1
  fi

  # Resolve absolute path and replace $HOME/ with nothing (relative path from home)
  target_path=${target_path:A}
  name="${target_path/#$HOME\//}"

  # If we're outside Zellij, start or attach to a session rooted in the target dir
  if [ -z "${ZELLIJ:-}" ]; then
    if ! (
      builtin cd "$target_path" || exit 1
      if [ -n "$layout" ]; then
        zellij --new-session-with-layout "$layout" --session "$name" ||
          zellij attach --create "$name"
      else
        zellij --session "$name" ||
          zellij attach --create "$name"
      fi
    ); then
      printf 'zt: failed to start zellij session\n' >&2
      return 1
    fi
    return 0
  fi

  # Open new tab in the target directory
  if [ -n "$layout" ]; then
    if ! zellij action new-tab --cwd "$target_path" --name "$name" --layout "$layout"; then
      printf 'zt: failed to open zellij tab\n' >&2
      return 1
    fi
  else
    if ! zellij action new-tab --cwd "$target_path" --name "$name"; then
      printf 'zt: failed to open zellij tab\n' >&2
      return 1
    fi
  fi
}
