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
alias gwip='git add -A && git commit -m "WIP"'
alias gundo='git reset HEAD~1 --mixed'
alias gconflicts='git diff --name-only --diff-filter=U'
alias gsup='git submodule update'
alias grv='git remote --verbose'

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
  local common_dir
  common_dir=$(git rev-parse --git-common-dir)
  local repo_root
  repo_root=$(cd "$common_dir/.." && pwd)

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
    wt_path="$repo_root/.worktrees/$branch_dir"
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

  # Ensure .worktrees is ignored locally
  if [ -d "$common_dir/info" ]; then
    if ! grep -q "^\.worktrees/" "$common_dir/info/exclude" 2>/dev/null; then
      echo ".worktrees/" >>"$common_dir/info/exclude"
    fi
  fi

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

# Interactive git branch switcher with preview
gcof() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'gcof: not inside a git repository\n' >&2
    return 1
  fi

  local branch
  branch=$(git branch --all --color=always |
    grep -v '/HEAD\s' |
    fzf --ansi \
        --height=50% \
        --preview 'git log --oneline --graph --color=always --date=short --format="%C(auto)%h %C(blue)%ad %C(auto)%d %C(reset)%s %C(cyan)(%an)" $(echo {} | sed "s/.* //" | sed "s#remotes/[^/]*/##") --' \
        --preview-window=right:60% \
        --bind 'ctrl-/:change-preview-window(down|hidden|)' \
        --header 'Ctrl-/ to toggle preview' |
    sed 's/.* //' |
    sed 's#remotes/[^/]*/##')

  if [[ -n "$branch" ]]; then
    git checkout "$branch"
  fi
}
