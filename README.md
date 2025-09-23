# Dotfiles

## What’s Inside

- Zsh and shell tooling
  - `zshrc` — shell setup, aliases, FZF, Starship, zoxide, mcfly, direnv
  - `plugins.zsh` — minimal plugin loader; auto‑clones syntax highlighting + autosuggestions
  - `editorconfig`, `gitconfig` — base editor and git UI (delta) settings
- Editors
  - Neovim (LazyVim): `config/nvim` (plugins + language extras)
  - Helix: `config/helix/config.toml`
- Terminal
  - Ghostty: `config/ghostty/config`
  - Zellij: `config/zellij/config.kdl`
- CLI tools configs
  - `config/bat/config`, `config/btop/btop.conf`, `config/mcfly/config.yaml`
- AI assistant `prompts`
  - Codex CLI prompts: `codex/prompts`
  - Claude agents/commands: `claude/agents`, `claude/commands/cm`
  - Gemini CLI commands: `gemini/commands`
- Plonk metadata
  - `plonk.yaml` (ignore patterns)
  - `plonk.lock` (discovered packages on this machine)

## Highlights & Conventions

- Shell defaults
  - Editor: `hx` (Helix); Neovim is configured and ready
  - FZF defaults: respects hidden files (excludes `.git`) with rich previews
  - Helpful aliases: `ll`, `files`, `dirs`, `lg` (lazygit), `stats` (tokei), `dps`, `du` (dust), `df` (duf)
  - Handy functions:
    - `y` — open yazi file manager and return to selected directory
    - `awsp` — set `AWS_PROFILE` via fuzzy selection
    - `fkill` — fuzzy kill a process (via `procs`)
    - `zrf` / `zef` — run/edit floating commands in Zellij
- Git
  - Pretty `delta` diffs, rebase merges on pull, autosquash, `trunk` default branch
- Neovim
  - LazyVim core with extras for: Go, Python, Rust, Terraform, Docker, Helm, JSON, YAML, Markdown, SQL, Git, TOML, Ansible
  - See `config/nvim/lazyvim.json` to tune extras
- Terminals
  - Ghostty config included; pick your preferred terminal

## AI Coding Agents

This repo includes ready‑to‑use prompts/command definitions for several AI coding CLIs. They are organized by tool and can be used as references or copied into your local CLI setups:

- Codex CLI: `codex/prompts`
  - Task‑focused prompts, e.g., generate docs or perform code reviews
- Claude Code: `claude/agents`, `claude/commands/cm`
  - Reusable “agents” (roles) and command files for common workflows
- Gemini CLI: `gemini/commands`
  - TOML command definitions for documentation and review flows

Usage varies by CLI; consult each tool’s docs and point the CLI to these files or copy them into the expected location for your setup.

## Credits

- Zsh plugin loader pattern inspired by zsh_unplugged
- LazyVim for a batteries‑included Neovim base

---

If you’re just browsing: this repo is a set of dotfiles you can borrow from wholesale or piece‑by‑piece. Enjoy!
