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

# Create a git worktree and immediately open it in a new Zellij tab.
zmkwt() {
  local layout="" branch wt_path wt_abs usage
  usage="Usage: zmkwt [--layout <name>] <branch> <worktree-path>"

  while [ $# -gt 0 ]; do
    case "$1" in
      --layout)
        shift
        if [ $# -eq 0 ]; then
          printf '%s\n' "$usage" >&2
          return 1
        fi
        layout="$1"
        shift
        ;;
      --layout=*)
        layout="${1#*=}"
        shift
        ;;
      --help|-h)
        printf '%s\n' "$usage"
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'zmkwt: unknown option %s\n%s\n' "$1" "$usage" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  if [ $# -ne 2 ]; then
    printf '%s\n' "$usage" >&2
    return 1
  fi

  branch="$1"
  wt_path="$2"

  if ! mkwt "$branch" "$wt_path"; then
    return $?
  fi

  if [ -d "$wt_path" ]; then
    wt_abs="$(cd "$wt_path" && pwd)"
  else
    wt_abs="$wt_path"
  fi

  printf 'Worktree ready: %s (%s)\n' "$wt_abs" "$branch"

  if ! command -v zellij >/dev/null 2>&1; then
    printf 'zmkwt: zellij not found; skipping tab creation\n' >&2
    return 0
  fi

  local cmd=(zellij action new-tab --cwd "$wt_abs")

  if [ -n "$layout" ]; then
    cmd+=(--layout "$layout")
  fi
  cmd+=(--name "$(basename "$wt_abs")")

  if ! "${cmd[@]}"; then
    printf 'zmkwt: failed to open zellij tab\n' >&2
    return 1
  fi
}

# Open a new Zellij tab, defaulting cwd to the current worktree.
ztab() {
  local layout="" target_path="" usage cwd
  usage="Usage: ztab [--layout <name>] [path]"

  while [ $# -gt 0 ]; do
    case "$1" in
      --layout)
        shift
        if [ $# -eq 0 ]; then
          printf '%s\n' "$usage" >&2
          return 1
        fi
        layout="$1"
        shift
        ;;
      --layout=*)
        layout="${1#*=}"
        shift
        ;;
      --help|-h)
        printf '%s\n' "$usage"
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'ztab: unknown option %s\n%s\n' "$1" "$usage" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  if [ $# -gt 1 ]; then
    printf '%s\n' "$usage" >&2
    return 1
  fi

  if [ $# -eq 1 ]; then
    target_path="$1"
  fi

  if [ -z "$target_path" ]; then
    if cwd="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      target_path="$cwd"
    else
      target_path="$PWD"
    fi
  fi

  if [ ! -d "$target_path" ]; then
    printf 'ztab: %s is not a directory\n' "$target_path" >&2
    return 1
  fi

  target_path="$(cd "$target_path" && pwd)"

  if ! command -v zellij >/dev/null 2>&1; then
    printf 'ztab: zellij not found\n' >&2
    return 127
  fi

  local cmd=(zellij action new-tab --cwd "$target_path")
  if [ -n "$layout" ]; then
    cmd+=(--layout "$layout")
  fi

  if ! "${cmd[@]}"; then
    printf 'ztab: failed to open zellij tab\n' >&2
    return 1
  fi
}

# Helper for zwork: format a worktree entry as display,branch,path.
__zellij__format_worktree_entry() {
  local repo_root="$1" path="$2" branch="$3"
  local branch_label marker display branch_store

  branch_label="${branch#refs/heads/}"
  if [ "$branch_label" = "HEAD" ] || [ -z "$branch_label" ]; then
    branch_label="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [ "$branch_label" = "HEAD" ] || [ -z "$branch_label" ]; then
      branch_label="detached"
    fi
  fi

  marker=""
  if [ "$path" = "$repo_root" ]; then
    marker="*"
  fi

  display="$marker$branch_label"
  branch_store=""
  if [ "$branch_label" != "detached" ]; then
    branch_store="$branch_label"
  fi

  printf '%s	%s	%s' "$display" "$branch_store" "$path"
}

# Jump to an existing git worktree, using fzf when available.
zwork() {
  local -a entries=()
  local line current_path="" current_branch="" repo_root selection entry

  if ! command -v git >/dev/null 2>&1; then
    printf 'zwork: git not found in PATH\n' >&2
    return 127
  fi

  if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'zwork: not inside a git repository\n' >&2
    return 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      worktree\ *)
        if [ -n "$current_path" ]; then
          entry="$(__zellij__format_worktree_entry "$repo_root" "$current_path" "$current_branch")"
          entries+=("$entry")
          current_branch=""
        fi
        current_path="${line#worktree }"
        ;;
      branch\ *)
        current_branch="${line#branch }"
        ;;
      "")
        if [ -n "$current_path" ]; then
          entry="$(__zellij__format_worktree_entry "$repo_root" "$current_path" "$current_branch")"
          entries+=("$entry")
          current_path=""
          current_branch=""
        fi
        ;;
    esac
  done < <(git worktree list --porcelain)

  if [ -n "$current_path" ]; then
    entry="$(__zellij__format_worktree_entry "$repo_root" "$current_path" "$current_branch")"
    entries+=("$entry")
  fi

  if [ ${#entries[@]} -eq 0 ]; then
    printf 'zwork: no worktrees found\n' >&2
    return 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    selection=$(printf '%s\n' "${entries[@]}" | fzf --delimiter=$'\t' --with-nth=1,3 --prompt='worktree> ' --header='Select worktree') || return 1
  else
    if [ ${#entries[@]} -eq 1 ]; then
      selection="${entries[0]}"
    else
      local i=1 choice line_entry display path
      for line_entry in "${entries[@]}"; do
        IFS=$'\t' read -r display _ path <<< "$line_entry"
        printf '%2d) %-20s %s\n' "$i" "$display" "$path" >&2
        i=$((i+1))
      done
      printf 'Select worktree: ' >&2
      read -r choice || return 1
      if [[ ! $choice = <-> ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#entries[@]} ]; then
        printf 'zwork: invalid selection\n' >&2
        return 1
      fi
      selection="${entries[$choice]}"
    fi
  fi

  IFS=$'\t' read -r _ _ current_path <<< "$selection"
  if [ -z "$current_path" ]; then
    printf 'zwork: failed to parse selection\n' >&2
    return 1
  fi

  local target="$current_path"
  if [ -d "$current_path" ]; then
    target="$(cd "$current_path" && pwd)"
  fi

  if builtin cd -- "$target"; then
    printf 'cd %s\n' "$PWD"
    return 0
  fi

  printf 'zwork: failed to cd into %s\n' "$target" >&2
  return 1
}

