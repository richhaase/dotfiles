# Dotfiles

## What’s Inside

- Top‑level files
  - `zshrc` — Primary zsh setup: PATH/env, history, completions, FZF, Starship, `zoxide`, `mcfly`, `direnv`, and a small plugin loader. Loads modular shell functions from `config/zsh/lib/*`.
  - `gitconfig` — Git identity, sensible defaults (delta pager, rerere, default branch), and a rich alias set (status/log helpers, worktree workflow).
  - `editorconfig` — Cross‑editor code style: UTF‑8, LF, 2‑space indent (4 for Go/Python), final newline, trim trailing whitespace.
  - `plonk.yaml` — [Plonk](https://github.com/richhaase/plonk) configuration file.
  - `plonk.lock` — [Plonk](https://github.com/richhaase/plonk) lockfile recording provisioned packages (brew, npm, pnpm, etc.). Serves as a reproducible inventory for a new machine.

- `bin/`
  - `bin/codex_notify.py` — Lightweight notifier for Codex CLI. On certain agent events (e.g., turn complete), sends a macOS notification via `terminal-notifier`.

- `config/` — Per‑application configuration
  - Prompt and shell
    - `config/starship.toml` — Starship prompt: concise status, git branch/state, direnv indicator, timings, and language versions. Disables heavy modules for speed.
    - `config/zsh/lib/` — Modular Zsh helpers:
      - `plugin_loader.sh` — Minimal “unplugged” plugin loader (clones and sources GitHub repos into `~/.config/zsh/plugins`).
      - `system.sh` — System/process helpers and aliases (e.g., `bat`, `duf`, `dust`, `weather`, `fkill`).
      - `files.sh` — File navigation with `eza`, `fd`, `bat`, and `yazi` integration that cds to the last dir on exit.
      - `tools.sh` — Dev‑tool shortcuts (e.g., `lg` for lazygit) and a Helix grammar helper.
      - `git.sh` — Git aliases and worktree utilities (`mkwt`, `rmwt`).
      - `zellij.sh` — Handy wrappers for Zellij (`zr`, `zp`, `ze`).
      - `aws.sh` — `awsp` to pick an `AWS_PROFILE` using `fzf`.
  - Editors & terminals
    - `config/helix/config.toml` — Helix editor UI/UX preferences: theme, cursor shapes, statusline, LSP, soft wrap, rulers, auto‑formatting.
    - `config/helix/languages.toml` — Language overrides; e.g., Python formatted with `ruff`, Dockerfile detection.
    - `config/ghostty/config` — Ghostty terminal font/theme and a simple keybind.
  - CLI tools
    - `config/bat/config` — Uses the Dracula theme.
    - `config/btop/btop.conf` — btop UI and graph preferences.
    - `config/zellij/` — Reserved for Zellij layouts/options.

- Agent/AI tooling presets
  - `claude/` — Claude Code agent prompts and roles (e.g., reviewer, researcher, doc generator). Markdown prompt packs live under `claude/agents/`.
  - `codex/prompts/` — Prompt files used by Codex CLI (e.g., code review, documentation). Includes a `cm/` set for common workflows.
  - `gemini/commands/` — Gemini CLI command TOML: ready‑to‑run prompts such as `code-review.toml` and `generate-docs.toml`.

---

If you are not me and are browsing these dotfiles: feel free to borrow ideas, but use at your own risk.
