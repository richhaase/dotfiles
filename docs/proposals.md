# Dotfiles Improvement Proposals

Status: Proposal 2 completed; others pending. Pick what you want and I’ll implement.

---

## 1) Starship Prompt Tuned For Your Workflow

- Why
  - Surface high‑signal context (direnv activation, language context for Python/JS-TS/Rust/Go, concise git) and keep prompt fast. No k8s or cloud modules.
- What
  - Add `config/starship.toml` with compact format, direnv + language modules (Python, Node.js, Rust, Go), trimmed git status, sane timeouts. Exclude k8s/AWS.
- How (example)
  ```toml
  # config/starship.toml
  format = "[ $directory ]($style) $git_branch$git_state$git_status$direnv$python$nodejs$rust$golang$status$cmd_duration$jobs\n$character"
  add_newline = true
  
  [directory]
  style = "bold blue"
  truncation_length = 3
  truncate_to_repo = true

  [git_branch]
  format = "[$symbol$branch]($style) "

  [git_status]
  format = "[$all_status$ahead_behind]($style) "
  conflicted = "✖"
  ahead = "⇡${count}"
  behind = "⇣${count}"
  diverged = "⇕"

  [python]
  format = "[($virtualenv )]($style)"
  pyenv_version_name = false
  only_virtualenv = true
  disabled = false

  [nodejs]
  format = "[node $version]($style) "
  detect_files = ["package.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb"]
  disabled = false

  [rust]
  format = "[rust $version]($style) "
  disabled = false

  [golang]
  format = "[go $version]($style) "
  disabled = false

  [direnv]
  format = "[⛶ direnv](bold cyan) "
  disabled = false

  [cmd_duration]
  min_time = 1500  # ms
  show_milliseconds = false

  # Keep things snappy by disabling rarely-used modules
  [package]
  disabled = true
  ```

---

## 2) Richer Completions with `zsh-users/zsh-completions`

Status: Completed (commit 965b5db)

- Why
  - Adds many community completions (git/docker/etc.) beyond Homebrew’s site functions.
- What
  - Load before autosuggestions and highlighting.
- How
  ```zsh
  # In zshrc plugin list
  plugins=(
    zsh-users/zsh-completions
    zsh-users/zsh-autosuggestions
  )
  plugin-load $plugins
  # zsh-syntax-highlighting remains loaded last (already handled in zshrc)
  ```

---

## 3) Unify Toolchains with `mise` (+ direnv)

- Why
  - One runtime manager for node/python/go/etc. via per‑project `.tool-versions`. Less PATH churn; reproducible shells.
- What
  - Use direnv to auto‑activate `mise` tool versions on cd.
- How
  ```zsh
  # zshrc (guarded init)
  (( $+commands[mise] )) && eval "$(mise activate zsh)"
  ```
  ```sh
  # .envrc in project
  use mise
  ```
  ```text
  # .tool-versions example (project root)
  nodejs 20.11.1
  python 3.12.4
  golang 1.22.5
  ```

---

## 4) Zellij “Resurrection” + Attach Behavior

- Why
  - Reopen terminal and pick up where you left off (panes/tabs/cwds).
- What
  - Enable session serialization; optionally auto‑attach to a named session.
- How
  ```kdl
  // config/zellij/config.kdl
  session_serialization true
  // optional:
  // session_name "main"
  // attach_to_session true
  ```
  ```zsh
  # zsh helper (optional)
  zj() { zellij attach -c ${1:-main}; }
  ```

---

## 5) Git QoL: `git-absorb` + `gh` flows

- Why
  - Absorb autosquash fixups automatically; faster PR/CI flows from the terminal.
- What
  - Add a couple of aliases around `git-absorb` and `gh`.
- How
  ```ini
  # in ~/.gitconfig or via `git config --global`
  [alias]
    abs = !git absorb --and-rebase
    prv = !gh pr view -w
    prc = !gh pr create -f
  ```

---

## 6) Fast Project Search Helpers (fzf + ripgrep)

- Why
  - Save keystrokes for everyday find/grep/branch navigation using tools you already have.
- What
  - Add 2–3 focused functions with previews.
- How
  ```zsh
  # config/zsh/lib/files.sh
  ff() { fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always --style=header,grid --line-range :200 {}'; }
  fg() { rg --hidden --line-number --no-heading --color=always -n "$@" | fzf --ansi --delimiter ':' \
           --preview 'bat --color=always --style=header,grid --line-range :200 {1} --highlight-line {2}' \
           --preview-window '+{2}-5'; }
  fb() { git for-each-ref --format='%(refname:short)' refs/heads | fzf | xargs -r git checkout; }
  ```

---

## 7) Starship Performance Hardening

- Why
  - Keep prompt responsive in large repos or remote shells.
- What
  - Disable slow/unneeded modules globally (cloud/k8s) and limit detection.
- How
  ```toml
  # config/starship.toml (in addition to Proposal 1)
  command_timeout = 800  # ms per module

  [python]
  detect_extensions = ["py"]
  detect_folders = [".venv", "venv"]

  [git_metrics]
  disabled = true

  # Not needed in your workflow
  [kubernetes]
  disabled = true
  [aws]
  disabled = true
  ```

---

## Notes / Next Steps

- Pick any subset; changes are independent.
- I’ll implement exactly what you approve, with guarded inits and minimal churn.
- If you later decide to remove Neovim entirely, nothing here depends on it.
