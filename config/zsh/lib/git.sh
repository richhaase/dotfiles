# ============================================================================
# Git Configuration
# ============================================================================

# Git aliases
alias branches='git branch --sort=-committerdate | head -10'
alias gst='git status'
alias gco='git checkout'
alias gcob='git checkout -b'
alias glog='git log --date=short --graph --format="%C(bold cyan)%h%C(reset) %C(red)%ad%C(auto)%d %C(reset)%s %C(cyan)(%an)"'
alias gp='git push'
alias gl='git pull'
alias ga='git add'
alias gc='git commit'
alias gca='git commit --amend --no-edit'
alias gclean='git branch --merged | grep -v "\*\|main\|trunk" | xargs git branch -d'
alias gfix='git add -A && git commit --fixup=HEAD'
alias gwip='git add -A && git commit -m "WIP"'

# Git worktree aliases
alias lswt='git worktree list'
alias rmwt='git worktree remove'

# Git worktree management - create worktree
mkwt() {
  if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'Usage: mkwt <branch> [worktree-path]\n' >&2
    return 1
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'mkwt: not inside a git repository\n' >&2
    return 1
  fi

  local branch="$1"
  local wt_path
  local force_flag=()

  branch="${branch%/}"
  if [ -z "$branch" ]; then
    printf 'mkwt: branch name cannot be empty\n' >&2
    return 1
  fi

  if [ "$#" -eq 1 ]; then
    local branch_dir="${branch##*/}"
    if [ -z "$branch_dir" ]; then
      branch_dir="$branch"
    fi
    wt_path="../$branch_dir"
  else
    wt_path="$2"
  fi

  if [ -e "$wt_path" ] && [ ! -d "$wt_path" ]; then
    printf 'mkwt: %s exists and is not a directory\n' "$wt_path" >&2
    return 1
  fi
  if [ -d "$wt_path" ] && [ -n "$(ls -A "$wt_path" 2>/dev/null)" ]; then
    printf 'mkwt: %s exists and is not empty\n' "$wt_path" >&2
    return 1
  fi

  mkdir -p -- "$(dirname "$wt_path")" || return 1

  if git worktree list --porcelain | grep -Fqx "branch $branch"; then
    force_flag=(--force)
  fi

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "${force_flag[@]}" "$wt_path" "$branch" >&2 || return $?
  elif git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    git fetch origin "$branch" >&2 || return $?
    git branch --track "$branch" "origin/$branch" >&2 || return $?
    git worktree add "${force_flag[@]}" "$wt_path" "$branch" >&2 || return $?
  else
    git worktree add "${force_flag[@]}" -b "$branch" "$wt_path" >&2 || return $?
  fi

  local wt_abs
  wt_abs="$(git -C "$wt_path" rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$wt_abs" ]; then
    case "$wt_path" in
      /*) wt_abs="$wt_path" ;;
      *) wt_abs="$PWD/$wt_path" ;;
    esac
  fi

  printf '%s\n' "$wt_abs"
  if [ ! -t 1 ] && [ -t 2 ]; then
    printf '%s\n' "$wt_abs" >&2
  fi
}

# Create a git worktree and open a Zellij tab with optional layout
# Usage: wzt <branch> [layout]
# For custom worktree paths, use: mkwt <branch> <path> && zt <path> [layout]
wzt() {
  if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'Usage: wzt <branch> [layout]\n' >&2
    return 1
  fi

  local wt_path layout

  layout="$2"

  if ! wt_path="$(mkwt "$1")"; then
    return $?
  fi

  if ! command -v zellij >/dev/null 2>&1; then
    printf 'wzt: zellij not found in PATH; worktree created at %s\n' "$wt_path" >&2
    printf '%s\n' "$wt_path"
    return 0
  fi

  if [ -n "$layout" ]; then
    if ! zt "$wt_path" "$layout"; then
      printf 'wzt: worktree created at %s, but failed to open zellij tab\n' "$wt_path" >&2
      printf '%s\n' "$wt_path"
      return 1
    fi
  else
    if ! zt "$wt_path"; then
      printf 'wzt: worktree created at %s, but failed to open zellij tab\n' "$wt_path" >&2
      printf '%s\n' "$wt_path"
      return 1
    fi
  fi

  printf '%s\n' "$wt_path"
}
