Generate or refresh project docs (README, SETUP, CONTRIBUTING, CHANGELOG) based on the repository.

Be practical and scannable; avoid marketing language. Use `rg`, `git`, and reading files to ground content.

Track progress explicitly using the plan tool (steps like: analyze repo, draft sections, present diffs, apply if approved).

Output proposed content for each selected doc as separate sections. After presenting drafts, ask for approval to write them. If approved, create or update the files.

Guidelines:

**README.md**
- One‑line description, quick start, key commands, installation, configuration
- Preserve useful existing content; remove redundancy; use concrete commands

**SETUP.md**
- Prerequisites, install steps, environment configuration, troubleshooting, verification

**CONTRIBUTING.md**
- Branching, coding style, test/lint requirements, PR checklist, commit style

**CHANGELOG.md**
- Follow Keep a Changelog; group by Features/Fixes/Breaking Changes using `git` history

When writing files, prefer minimal, high‑value edits and include copy‑paste‑ready commands.

Instructions:

- Present the list of documentation that you can generate as a menu mapping each document to a number.  You will accept either name(s) or number(s) as input documents to update.
- Prompt the user for which document(s) they would like generated or updated.
- Generate or update the user requested documents.
