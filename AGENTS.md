# Repository Guidelines

## Project Structure & Module Organization
The root contains the only hand-edited entry points: `zshrc`, `gitconfig`, `editorconfig`, `plonk.yaml`, and `plonk.lock`. Executables live in `bin/` (e.g., `bin/codex_notify.py`). App-specific settings stay inside `config/`: `config/zsh/lib/*.sh` for shell modules, `config/helix/` for editor behavior, and `config/ghostty/` for terminal defaults. AI prompt packs are vendor-scoped (`claude/`, `codex/prompts/`, `gemini/commands/`); add new prompts beside their peers using descriptive names like `role-skill.md`.

## Build, Test, and Development Commands
- `plonk apply` — Provision every declared tool after editing `plonk.yaml` or setting up a new host.
- `plonk doctor` — Report drift between the lockfile and the machine.
- `zsh -n zshrc config/zsh/lib/*.sh` — Syntax-check login scripts before committing.
- `shellcheck config/zsh/lib/*.sh` — Enforce portable shell style.
- `python -m compileall bin/*.py` — Quick regression net for Python helpers.

## Coding Style & Naming Conventions
`.editorconfig` rules everything: UTF-8, LF endings, two-space indent unless Go/Python (four). Shell files stay lowercase with hyphenated names; functions use snake_case verbs plus nouns. `bin/` scripts must be executable, start with a usage comment, and expose `--help`. Keep comments brief and intent focused.

## Testing Guidelines
Exercise edited shell helpers in a clean `zsh` session and verify each alias touched. `zsh -n` and `shellcheck` must pass with zero warnings. Python utilities should include a minimal `main` guard; when behavior changes, add tests under `tests/` (create if missing) and run `python -m unittest discover`.

## Commit & Pull Request Guidelines
Commits follow the repository pattern of short, imperative, sub-50-character subjects (“Fix plonk package names”). Use bodies for rationale and issue links. Pull requests describe user-facing impact, call out new dependencies, and attach screenshots or terminal captures for UI or prompt tweaks. Rebase before opening.

## Security & Configuration Tips
Keep host secrets out of version control; extend `plonk.yaml` ignores if new tools cache tokens elsewhere. Pin third-party plugins via `config/zsh/lib/plugin_loader.sh` and note upgrade steps so future installs stay reproducible.
