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
    git worktree add "${force_flag[@]}" "$wt_path" "$branch"
    return $?
  fi

  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    git fetch origin "$branch" || return $?
    git branch --track "$branch" "origin/$branch" || return $?
    git worktree add "${force_flag[@]}" "$wt_path" "$branch"
    return $?
  fi

  git worktree add "${force_flag[@]}" -b "$branch" "$wt_path"
}

# Git worktree management - remove worktree
rmwt() {
  local opt force_flag=() wt_path wt_abs
  OPTIND=1
  while getopts ":f" opt; do
    case "$opt" in
      f) force_flag=(--force) ;;
      \?) printf 'rmwt: invalid option -- %s\n' "$OPTARG" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND-1))

  if [ "$#" -ne 1 ]; then
    printf 'Usage: rmwt [-f] <worktree-path>\n' >&2
    return 1
  fi
  wt_path="$1"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'rmwt: not inside a git repository\n' >&2
    return 1
  fi

  if [ -d "$wt_path" ]; then
    wt_abs="$(cd "$wt_path" && pwd)"
  else
    wt_abs="$(cd "$(dirname "$wt_path")" 2>/dev/null && pwd 2>/dev/null)/$(basename "$wt_path")"
  fi

  if ! git worktree list --porcelain | grep -Fqx "worktree $wt_abs"; then
    printf 'rmwt: %s is not a registered worktree\n' "$wt_path" >&2
    return 1
  fi

  git worktree remove "${force_flag[@]}" "$wt_path"
}
