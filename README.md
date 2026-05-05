# Dotfiles
Plonk-managed dotfiles for reproducing a macOS/zsh development host with one apply.

## Quick Start
1. Clone into `$PLONK_DIR` (defaults to `~/src/dotfiles`):
   ```bash
   git clone git@github.com:richhaase/dotfiles.git ~/src/dotfiles
   cd ~/src/dotfiles
   ```
2. Provision everything declared in `plonk.lock`:
   ```bash
   plonk apply
   ```
3. Verify the install and shell scripts:
   ```bash
   plonk status
   zsh -n zshrc config/zsh/lib/*.sh
   shellcheck config/zsh/lib/*.sh
   ```

## Installation
- **Prerequisites**: macOS with Homebrew, Git, Plonk, and zsh as your login shell.
- **Prepare**: Back up conflicting dotfiles, then review `plonk.yaml` and `plonk.lock` to see which directories and tools will sync into `$HOME`.
- **Apply**: Run `plonk apply` after any change or when setting up a new machine. Plonk expands the directories listed under `expand_directories` while respecting `ignore_patterns`.
- **Troubleshooting**:
  - `plonk status` surfaces drift between the lockfile and the host before applying.
  - Inspect pending edits with `git status` inside `$PLONK_DIR`.
  - Re-run the shell lint commands above whenever you change anything under `config/zsh/lib/`.

## Key Commands
- `plonk apply` — Provision or reconcile everything declared in `plonk.lock`.
- `plonk status` — Show drift between the current host and `plonk.lock`.
- `plonk add <path>` — Track a new dotfile or sync an edited one into the repo.
- `plonk push` / `plonk pull` — Move plonk-managed commits to/from the remote.
- `zsh -n zshrc config/zsh/lib/*.sh` — Syntax-check login scripts before committing.
- `shellcheck config/zsh/lib/*.sh` — Enforce portable shell style.

## Directory Map
- `zshrc` — Primary zsh entry point: PATH/env setup, completions, plugin loader, and tool inits for Starship, Atuin, fnm, zoxide, and direnv.
- `gitconfig` — Identity, delta paging, rerere, and other git defaults.
- `tmux.conf` — Multiplexer config (prefix `C-a`, vim-style pane motion).
- `editorconfig` — Canonical formatting rules (UTF-8, LF, 2-space indent except Go/Python).
- `plonk.yaml` / `plonk.lock` — Plonk manifest + lockfile describing every provisioned tool.
- `bin/` — User scripts (e.g., `bin/sync-repos`); keep them executable and provide `--help`.
- `config/zsh/lib/` — Shell modules: `plugin_loader.sh` (pinned plugin installer) and `aliases.sh` (aliases + helper functions).
- `config/helix/` — Helix editor defaults plus language overrides.
- `config/kitty/`, `config/bat/`, `config/atuin/` — Terminal, pager, and shell-history preferences.
- `config/starship.toml` — Prompt config.
- `codex/`, `gemini/commands/` — AI/agent prompt and config files, grouped by vendor.

## Configuration & Customization
- **Shell modules**: Drop new helpers into `config/zsh/lib/` (lowercase, hyphenated filenames, snake_case functions). Run the lint commands before committing.
- **App settings**: Extend `config/helix/*.toml`, `config/kitty/kitty.conf`, or other per-app configs to tweak editor/terminal behavior.
- **Prompt packs**: Place new agent prompts under the matching vendor directory with a descriptive filename; keep secrets out of version control.
- **Plugins**: Pin third-party zsh plugins via `config/zsh/lib/plugin_loader.sh` to keep installs reproducible.
