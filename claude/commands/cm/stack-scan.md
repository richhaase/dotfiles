---
description: >-
  Delegate to cm-stack-profiler subagent for comprehensive technology stack
  analysis
argument-hint: '[overwrite|append|skip]'
allowed-tools: 'Task, Write, Edit'
plan_mode: 'true'
---
# Intent

Delegate stack analysis to the specialized cm-stack-profiler subagent for comprehensive technology profiling.

# Procedure

1. **Check for existing stack.md**: Look for .cm/stack.md file first
2. **If stack.md exists**: Read and summarize the existing stack information
3. **If no stack.md**: Invoke cm-stack-profiler to scan and analyze stack
4. **cm-stack-profiler analyzes**: Scans languages, frameworks, tools, dependencies (only when needed)
5. **Structured output**: Provides:
   - Stack summary from existing file OR complete technology stack inventory
   - Build/test/run commands
   - Entry points and hot paths
   - External service dependencies
   - Development setup instructions
   - Optimization recommendations (when rescanning)

# Execution

When this command runs, Claude Code will:

1. Check if .cm/stack.md exists:
   - **If exists**: Read and provide a concise summary of the current stack
   - **If missing**: Use Task tool to invoke the cm-stack-profiler subagent

2. Use Task tool to invoke the cm-stack-profiler subagent with:
  - subagent_type: "cm-stack-profiler"
  - prompt: Request stack analysis with action from $ARGUMENTS
  - description: "Analyze technology stack"

3. Handle .cm/stack.md file (only when rescanning):
   - No file exists: Create with detected stack profile
   - `overwrite`: Replace existing file
   - `append`: Add new dated section
   - `skip`: Show profile in chat only
   - No args: Ask user what to do

The cm-stack-profiler subagent specializes in:
- Multi-language ecosystem detection
- Build tool and dependency analysis
- Development workflow optimization
- Service integration identification
- Performance and tooling recommendations

The detective provides actionable intelligence for immediate productivity.
