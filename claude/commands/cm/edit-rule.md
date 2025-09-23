---
description: >-
  Edit an existing rule in .cm/rules.md by slug or title. Preserves delimiters.
  Creates file if missing.
argument-hint: <slug-or-title>
allowed-tools: 'Read, Grep, Glob, Edit, Write'
---
# Intent

Help the user update a rule in `.cm/rules.md` while preserving its delimiter block. If the file is missing, create it with a minimal header and then add the rule as if using `/add-rule`.

# Interaction flow

1. **Locate the rule**:
   - Accept either a slug (from <!-- RULE-BEGIN: ... slug -->) or a title match.
   - If multiple matches → list them and ask user to choose.
   - If no match → ask if the user wants to create a new rule instead.

2. **Collect updates**:
   - Ask which fields to edit (Title, Level, Directive, Scope, Rationale, Exceptions).
   - Use RFC 2119 keywords (MUST, MUST NOT, SHOULD, SHOULD NOT, MAY) for the directive.
   - Validate the directive as in `/add-rule` (exactly one RFC keyword in UPPERCASE).

3. **Prepare new block**:
   - Keep the same slug, update the timestamp to the current ISO 8601 time.
   - Replace only the edited fields; keep other fields unchanged.
   - Preserve <!-- RULE-BEGIN/END --> delimiters.

4. **Write changes**:
   - Ask once for confirmation before writing back to `.cm/rules.md`.
   - If declined, show the updated block without writing.

# File header (if creating .cm/rules.md)

If `.cm/rules.md` does not exist, create with:

```md
# Project Development Rules

Rules below are normative and use RFC 2119 language (MUST, SHOULD, MAY, etc.).
Edit or remove rules with care; each rule is delimited for easy maintenance.
```

# Rule block format (unchanged, must be preserved)

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

- Always preserve delimiters and the trailing `---` line.
- Never silently overwrite rules. Always ask before saving edits.
- If user provides updated content inline, skip Q&A and go straight to validation and confirmation.
