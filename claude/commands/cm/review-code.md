---
description: Delegate to cm-reviewer subagent for comprehensive code review
argument-hint: '[commit-range | file-paths | HEAD~1]'
allowed-tools: 'Bash(git:*), Task'
plan_mode: 'true'
---
# Intent

Delegate code review to the specialized cm-reviewer subagent for comprehensive analysis of changes.

# Procedure

1. **Gather changes**: Get git diff based on arguments
   - No arguments → review uncommitted changes (`git diff HEAD`)
   - Commit range → review range (`git diff main..HEAD`)
   - File paths → review specific files (`git diff HEAD -- file.js`)
   - HEAD~N → review last N commits

2. **Invoke subagent**: Pass diff to cm-reviewer subagent

3. **Subagent provides**: Structured review with:
   - 🔴 CRITICAL (Must Fix) - bugs, security issues
   - 🟡 WARNINGS (Should Fix) - maintainability, performance
   - 🟢 SUGGESTIONS (Consider) - enhancements, alternatives
   - ✅ GOOD PRACTICES - positive reinforcement

# Execution

When this command runs, Claude Code will:

1. Use Bash tool to get the appropriate git diff based on $ARGUMENTS
2. Use Task tool to invoke the cm-reviewer subagent with:
  - subagent_type: "cm-reviewer"
  - prompt: Include the diff output and request for code review
  - description: "Code review of changes"

The cm-reviewer subagent will analyze the changes with senior engineer expertise, checking for correctness, design, security, performance, and style issues.
