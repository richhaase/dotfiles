---
description: >-
  Add a project rule to .cm/rules.md using RFC 2119 language (MUST/SHOULD/MAY).
  Creates the file if missing.
argument-hint: '[level] [short title] — optionally pass a draft directive'
allowed-tools: 'Read, Grep, Glob, Edit, Write'
---
# Intent

Help the user add a **single rule** to `.cm/rules.md`, formatted with **RFC 2119** keywords and delimited so rules are easy to manage. If `.cm/rules.md` does not exist, create it with a minimal header.

# RFC 2119 reference (for the user)

Use one of: **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, **MAY**.

# Interaction flow (targeted, minimal)

1. **Collect** the pieces (ask only what’s missing):
   - **Title** (short, imperative)
   - **Level** (MUST / MUST NOT / SHOULD / SHOULD NOT / MAY)
   - **Directive** (one sentence that includes the RFC keyword in UPPERCASE)
   - Optional: **Scope** (paths/components this applies to)
   - Optional: **Rationale** (why this exists)
   - Optional: **Exceptions** (narrowly-defined, if any)

2. **Validate** the directive:
   - Ensure it contains exactly one RFC keyword in UPPERCASE.
   - Keep it a single, clear sentence (rewrite concisely if needed).
   - If the directive duplicates an existing rule (by similar title or overlapping directive), **warn once** and ask whether to proceed or cancel.

3. **Prepare** the entry:
   - Create a stable **slug** from the title (kebab-case).
   - Compose a delimited block (see format below) with an ISO 8601 timestamp.

4. **Write rule**:
   - If `.cm/rules.md` is missing → create it with a brief header, then append the new block.
   - If present → append the new block at the end.
   - **Ask once** for confirmation before writing. If declined, show the block and do not write.

# File header (only when creating .cm/rules.md)

If the file doesn’t exist, write this at the top before appending the first rule:

```md
# Project Development Rules

Rules below are normative and use RFC 2119 language (MUST, SHOULD, MAY, etc.).
Edit or remove rules with care; each rule is delimited for easy maintenance.
```

# Rule block format (append exactly as shown)

```md
<!-- RULE-BEGIN: {timestamp} {slug} -->

## {title}

**Level:** {MUST|MUST NOT|SHOULD|SHOULD NOT|MAY}
**Directive:** {single-sentence directive containing the RFC keyword}
**Scope:** {optional, e.g., paths/modules}
**Rationale:** {optional}
**Exceptions:** {optional}

## <!-- RULE-END: {slug} -->
```

# Notes

- Keep **one rule per block**. The `<!-- RULE-BEGIN/END -->` comments and trailing `---` delimiter separate rules cleanly.
- Do not perform code edits or run shell commands. This command only reads/writes `.cm/rules.md`.
- If the user provides all fields in one go, skip questions and go straight to validation → confirm write.
