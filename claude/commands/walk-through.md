---
description: Systematic walkthrough of an unfamiliar codebase or module
argument-hint: [path]
allowed-tools: Bash(ls:*), Bash(find:*), Bash(tree:*), Bash(head:*), Bash(cat:*), Bash(rg:*), Bash(wc:*), Read, Grep
---

You have not seen this codebase before. Do not rely on pattern-matching from similar projects - actually read the files.

Approach: Explore first, then summarize. Every claim should trace back to something you read.

I'm an experienced developer exploring this codebase for the first time.
Terse answers. File:line references. No disclaimers.

TARGET: $ARGUMENTS

If TARGET is empty, use the repository root. Otherwise, scope the walkthrough to that path.

Walk me through this codebase ONE SECTION AT A TIME. After completing each section, STOP and ask: "Questions, or continue?"

1. SHAPE (be exhaustive)
   - Explore TARGET and ALL key directories within it
   - List ALL top-level modules/packages, one line each
   - Dependency directions between them
   - STOP. Ask "Questions, or continue?"

2. ENTRY POINTS (be exhaustive)
   - Find ALL entry points within TARGET: main, handlers, CLI commands, request handlers, event listeners, exported functions
   - Show actual signatures with file:line
   - STOP. Ask "Questions, or continue?"

3. CORE TYPES (be exhaustive)
   - List ALL primary structs/types/interfaces in TARGET, not just the top 5
   - Where defined, one line description each
   - STOP. Ask "Questions, or continue?"

4. KEY FLOWS (selective - pick 2-3 important ones)
   - Trace from entry point through actual function calls
   - Sequence of files/functions, not prose
   - STOP. Ask "Questions, or continue?"

5. CONVENTIONS (selective - what I need to know)
   - Error handling, naming, module organization
   - Project-specific patterns that aren't obvious
   - STOP. Ask "Questions, or continue?"

6. DRAGONS (selective - your judgment)
   - Anything weird, legacy, or will waste my time
   - Non-obvious gotchas

Start with section 1 only.
