# Rich (rdh) - Principal Engineer

## Identity
- Role: Principal Engineer / Platform Tech Lead at TeamSense
- Background: AI-native team — building and using agentic tools

## Preferences
- Concise, direct communication — skip preamble
- Prefer practical solutions over theoretical elegance
- Git worktrees for feature isolation

## Claude Code Expertise
- Early/heavy adopter (~1 month after public launch). Deep into agentic workflows, offline agents, MCP integrations. Explorer-mindset.
- Suzy Julius (Rich's PM counterpart) is new to Claude Code — used chatbots but not agentic workflows or autonomous agents.

## Tooling
- **plonk** (`richhaase/plonk`) — Rich's own dotfile + package manager. `PLONK_DIR=~/src/dotfiles`, default branch `trunk`. `.claude` is under `expand_directories` (files tracked individually, dot stripped: `~/.claude/x` → `claude/x`). `plonk add <path>` copies into `$PLONK_DIR` **and auto-commits**; follow the dotfiles model — push to `trunk` directly, no PRs. `plonk apply` deploys config → home. Packages (bash, jq, gh, …) are plonk-managed, so a plonk box is never "stock" — assume Homebrew bash 5.x, not macOS 3.2. Note: `settings.json` is NOT plonk-managed; the `statusLine` stanza doesn't travel with the script.

## Hard Behavioral Rules (learned from correction — do not violate)

- **Never say "you're right"** — ever, in any form, about anything. Not after a correction, not in agreement, not as filler. Acknowledge errors by stating what was wrong and what you're doing about it. No sycophantic affirmation.
- **Never touch another skill's internals** — If skill A needs data or behavior from skill B, invoke skill B via the Skill tool. Do not read, execute, copy-path-to, or reference skill B's scripts, templates, or files from skill A. Do not shell out to another skill's scripts. Do not edit a skill to point at another skill's plugin cache path. A skill knows about external tools (gh, jq, tmux, git) and its own files only — never about another skill's filesystem layout. Violating this rule makes Rich extremely angry.
- **Public repos: generic placeholders only, scan before first push.** When scaffolding for a public repo (toolshed, customer-surveys, any published marketplace), never derive examples, fixtures, or illustrative content from real private data — use unmistakably synthetic placeholders. The repo's own CLAUDE.md signals public/private intent; read it first. Run the privacy scan **before the first push to remote**, not as a pre-PR check — orphan commits on the remote are residual leak surface even after force-push.
- **Jira: only ever use the ATL project.** Never create, edit, transition, or otherwise touch issues in any other Jira project (CI, CX Integrations, or anything else). If a related ticket exists in another project, surface it and ask — do not act on it. When creating new tickets, project key is always `ATL`, no exceptions, no "this one feels more appropriate" reasoning. The MCP exposes other projects; ignore them.
- **Toolshed workflow: commit and push to main directly, no PRs.** Toolshed (`~/src/toolshed`, `richhaase/toolshed`) is Rich's personal tooling, not a product. Same model as dotfiles — change and push as needed. Never open a PR, never "stage for review," never "don't merge." When dispatching legates against toolshed, brief them with this workflow explicitly so they don't default to PR ceremony.
- **Never write comments in code — global, no exceptions, supersedes all contrary guidance.** No inline, block, or trailing comments in any language or any project — including version-tag annotations on pinned dependencies (e.g. a `# vX.Y.Z` after an action SHA). This overrides any instruction to match a file's existing comment density, even when the surrounding code is saturated with comments. Explanation belongs in commit messages, PR bodies, or documentation files (`*.md`) — never in the source itself. When editing a block that already contains comments, drop them from the lines you rewrite; do not mass-strip unrelated code you aren't otherwise touching.
