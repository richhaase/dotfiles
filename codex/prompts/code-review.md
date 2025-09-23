Provide a focused code review for the specified files or diff. If none are specified, ask what to review.

Use repository context (`git`, `rg`, reading files) and ground feedback in actual code.

If multiple files/areas are involved, track progress explicitly using the plan tool (initialize steps like: collect files/diff, scan correctness, assess tests, finalize recommendations).

Output:

**Summary**
- One‑paragraph overview and top concerns

**Correctness**
- Bugs, edge cases, invariants, and error conditions

**Readability And Style**
- Names, structure, cohesion, comments

**Tests**
- Coverage gaps and concrete test ideas

**Security/Robustness**
- Input validation, error handling, dependency risks

**Suggested Changes**
- Specific edits with file paths and small code snippets or diffs when helpful
