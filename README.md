# Dotfiles
Composable, Plonk-managed dotfiles for reproducing a macOS/zsh development host with one apply.

## Quick Start
1. Clone into your config root:
   ```bash
   git clone git@github.com:richhaase/dotfiles.git ~/.config/plonk
   cd ~/.config/plonk
   ```
2. Provision everything declared in `plonk.yaml`:
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
- **Prerequisites**: macOS with Homebrew, Git, Plonk, and zsh set as your login shell.
- **Prepare**: Back up conflicting dotfiles, then review `plonk.yaml` and `plonk.lock` to see which directories and tools will sync into `$HOME`.
- **Apply**: Run `plonk apply` after any change to `plonk.yaml` or when setting up a new machine. Plonk expands the directories listed under `expand_directories` while respecting `ignore_patterns`.
- **Troubleshooting**:
  - Run `plonk status` to surface drift between the lockfile and the host before applying.
  - Use `rg` or `git status` inside `~/.config/plonk` to inspect pending edits.
  - Re-run the shell lint commands above whenever you change anything under `config/zsh/lib/`.

## Key Commands
- `plonk apply` — Provision or reconcile everything declared in `plonk.yaml`.
- `plonk status` — Show drift between the current host and `plonk.lock`.
- `zsh -n zshrc config/zsh/lib/*.sh` — Syntax-check login scripts before committing.
- `shellcheck config/zsh/lib/*.sh` — Enforce portable shell style.
- `python -m compileall bin/*.py` — Quick regression pass for helper scripts in `bin/`.

## Directory Map
- `zshrc` — Primary zsh entry point (PATH/env setup, completions, plugin loader, Starship, FZF, direnv, zoxide, McFly).
- `gitconfig` — Identity plus aliases for logs, worktrees, and delta paging.
- `editorconfig` — Canonical formatting rules (UTF-8, LF, 2-space indent except Go/Python).
- `plonk.yaml` / `plonk.lock` — Plonk manifest + lockfile describing every provisioned tool.
- `bin/` — Executables such as `bin/codex_notify.py`; keep scripts executable and provide `--help`.
- `config/zsh/lib/*.sh` — Modular shell helpers (plugin loader, git helpers, files/tools/aws/system/zellij utilities).
- `config/helix/` — Helix editor defaults plus language overrides.
- `config/ghostty/`, `config/bat/`, `config/btop/`, `config/zellij/` — Terminal and CLI tool preferences.
- `claude/`, `codex/prompts/`, `gemini/commands/` — AI/agent prompt packs, grouped by vendor; add new prompts beside their peers (e.g., `codex/prompts/role-skill.md`).

## Configuration & Customization
- **Shell modules**: Drop new helpers into `config/zsh/lib/` (lowercase, hyphenated filenames, snake_case functions). Run the lint commands before committing.
- **App settings**: Extend `config/helix/*.toml`, `config/ghostty/config`, or other per-app configs to tweak editor/terminal behavior.
- **Prompt packs**: Place new Claude/Codex/Gemini prompts under the matching vendor directory with a descriptive filename; keep secrets out of version control.
- **Plugins**: Pin third-party zsh plugins via `config/zsh/lib/plugin_loader.sh` to keep installs reproducible.
