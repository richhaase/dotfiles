#!/usr/bin/env bash
# Claude Code status line — mirrors Starship prompt aesthetic
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
branch=$(echo "$input" | jq -r '.worktree.branch // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten the path like Starship (keep last components, replace $HOME with ~)
# Note: the ~ replacement MUST be escaped (\~) — bash 5.2+ otherwise treats a
# bare ~ in a substitution replacement specially and the replacement no-ops.
home="$HOME"
short_cwd="${cwd/#$home/\~}"
IFS='/' read -ra parts <<< "$short_cwd"
count="${#parts[@]}"
if (( count > 3 )); then
  if [ "${parts[0]}" = "~" ]; then
    # Keep the home anchor: ~/…/parent/current
    short_cwd="~/…/${parts[-2]}/${parts[-1]}"
  else
    short_cwd="…/${parts[-3]}/${parts[-2]}/${parts[-1]}"
  fi
fi

# Git branch (from workspace if not in a worktree)
if [ -z "$branch" ]; then
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Build output
out=""

# Directory (bold blue)
out+="\033[1;34m${short_cwd}\033[0m"

# Git branch (bold purple)
if [ -n "$branch" ]; then
  out+=" \033[1;35m \033[0m\033[1;35m${branch}\033[0m"
fi

# Git working-tree status (Starship-style): staged/modified/untracked/conflicts + ahead/behind.
# One porcelain call; --no-optional-locks avoids fighting a concurrent git for the index lock.
# Only non-zero counts render, so a clean+synced tree shows just the branch. Silent outside a repo.
if [ -n "$branch" ]; then
  gstat=$(git -C "$cwd" --no-optional-locks status --porcelain=v1 --branch 2>/dev/null)
  if [ -n "$gstat" ]; then
    g_staged=0; g_mod=0; g_untracked=0; g_conflict=0; g_ahead=0; g_behind=0
    while IFS= read -r gl; do
      [ -z "$gl" ] && continue
      if [ "${gl:0:2}" = "##" ]; then
        [[ "$gl" =~ ahead\ ([0-9]+) ]] && g_ahead="${BASH_REMATCH[1]}"
        [[ "$gl" =~ behind\ ([0-9]+) ]] && g_behind="${BASH_REMATCH[1]}"
        continue
      fi
      gx="${gl:0:1}"; gy="${gl:1:1}"
      if [ "${gl:0:2}" = "??" ]; then
        g_untracked=$((g_untracked+1))
      elif [ "$gx" = "U" ] || [ "$gy" = "U" ] || [ "${gl:0:2}" = "DD" ] || [ "${gl:0:2}" = "AA" ]; then
        g_conflict=$((g_conflict+1))
      else
        [ "$gx" != " " ] && g_staged=$((g_staged+1))
        [ "$gy" != " " ] && g_mod=$((g_mod+1))
      fi
    done <<< "$gstat"
    gseg=""
    (( g_conflict  > 0 )) && gseg+=" \033[1;31m=${g_conflict}\033[0m"   # conflicts (red)
    (( g_staged    > 0 )) && gseg+=" \033[1;32m+${g_staged}\033[0m"     # staged (green)
    (( g_mod       > 0 )) && gseg+=" \033[1;33m!${g_mod}\033[0m"        # modified (yellow)
    (( g_untracked > 0 )) && gseg+=" \033[2;37m?${g_untracked}\033[0m"  # untracked (dim)
    (( g_ahead     > 0 )) && gseg+=" \033[1;36m⇡${g_ahead}\033[0m"      # ahead (cyan)
    (( g_behind    > 0 )) && gseg+=" \033[1;36m⇣${g_behind}\033[0m"     # behind (cyan)
    out+="$gseg"
  fi
fi

# Model (dim white)
if [ -n "$model" ]; then
  out+=" \033[2;37m${model}\033[0m"
fi

# Context usage (dim cyan, only after first message)
if [ -n "$used" ]; then
  printf -v used_int "%.0f" "$used"
  if (( used_int >= 80 )); then
    ctx_color="\033[1;31m"
  elif (( used_int >= 50 )); then
    ctx_color="\033[1;33m"
  else
    ctx_color="\033[2;36m"
  fi
  out+=" ${ctx_color}ctx:${used_int}%\033[0m"
fi

# Rate-limit usage (dim magenta; shows 5h limit when available, falls back to 7d)
# Uses pre-calculated used_percentage fields — degrades silently when absent.
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$five_pct" ] || [ -n "$seven_pct" ]; then
  rl_parts=""
  if [ -n "$five_pct" ]; then
    printf -v five_int "%.0f" "$five_pct"
    rl_parts="5h:${five_int}%"
  fi
  if [ -n "$seven_pct" ]; then
    printf -v seven_int "%.0f" "$seven_pct"
    [ -n "$rl_parts" ] && rl_parts+=" "
    rl_parts+="7d:${seven_int}%"
  fi
  out+=" \033[2;35m${rl_parts}\033[0m"
fi

# PR badge — cached lookup keyed by repo+branch to avoid network on every render.
# Cache TTL: 60 seconds. Degrades silently if gh is absent or unauthenticated.
if [ -n "$branch" ] && command -v gh &>/dev/null; then
  repo_owner=$(echo "$input" | jq -r '.workspace.repo.owner // empty')
  repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty')
  if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
    cache_dir="${TMPDIR:-/tmp}/claude-statusline-pr-cache"
    mkdir -p "$cache_dir"
    # Sanitise branch name for use as a filename
    safe_branch="${branch//\//_}"
    cache_file="${cache_dir}/${repo_owner}_${repo_name}_${safe_branch}.json"
    now=$(date +%s)
    cache_valid=0
    if [ -f "$cache_file" ]; then
      cache_mtime=$(stat -f "%m" "$cache_file" 2>/dev/null || stat -c "%Y" "$cache_file" 2>/dev/null || echo 0)
      age=$(( now - cache_mtime ))
      (( age < 60 )) && cache_valid=1
    fi
    if [ "$cache_valid" -eq 0 ]; then
      # Non-blocking fetch; write atomically so a partial write is never read.
      tmp_cache="${cache_file}.tmp.$$"
      gh pr view "$branch" \
        --repo "${repo_owner}/${repo_name}" \
        --json number,reviewDecision,isDraft,state,statusCheckRollup \
        2>/dev/null > "$tmp_cache" && mv "$tmp_cache" "$cache_file" || rm -f "$tmp_cache"
    fi
    if [ -f "$cache_file" ]; then
      pr_number=$(jq -r '.number // empty' "$cache_file" 2>/dev/null)
      pr_state=$(jq -r '.state // empty' "$cache_file" 2>/dev/null)
      if [ -n "$pr_number" ] && [ "$pr_state" = "OPEN" ]; then
        pr_review=$(jq -r '.reviewDecision // empty' "$cache_file" 2>/dev/null)
        pr_draft=$(jq -r '.isDraft // false' "$cache_file" 2>/dev/null)
        if [ "$pr_draft" = "true" ]; then
          pr_badge="PR #${pr_number} draft"
          pr_color="\033[2;37m"
        elif [ "$pr_review" = "APPROVED" ]; then
          pr_badge="PR #${pr_number} approved"
          pr_color="\033[2;32m"
        elif [ "$pr_review" = "CHANGES_REQUESTED" ]; then
          pr_badge="PR #${pr_number} changes"
          pr_color="\033[2;31m"
        else
          pr_badge="PR #${pr_number}"
          pr_color="\033[2;33m"
        fi
        out+=" ${pr_color}${pr_badge}\033[0m"
        # CI rollup state — separate glyph so its colour is independent of the
        # review-state colour. Reduces the check rollup to fail/pending/pass.
        ci_state=$(jq -r '
          [ .statusCheckRollup[]? | (.conclusion // .state // .status // empty) ] as $s
          | if   ($s | map(select(. == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT" or . == "ACTION_REQUIRED")) | length) > 0 then "fail"
            elif ($s | map(select(. == "PENDING" or . == "QUEUED" or . == "IN_PROGRESS" or . == "EXPECTED")) | length) > 0 then "pending"
            elif ($s | length) == 0 then ""
            else "pass" end
        ' "$cache_file" 2>/dev/null)
        case "$ci_state" in
          pass)    out+=" \033[2;32m✓\033[0m" ;;
          fail)    out+=" \033[2;31m✗\033[0m" ;;
          pending) out+=" \033[2;33m●\033[0m" ;;
        esac
      fi
    fi
  fi
fi

printf "%b\n" "$out"
