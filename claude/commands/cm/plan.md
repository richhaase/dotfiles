---
description: Delegate to cm-planner subagent for comprehensive implementation planning
argument-hint: <goal…>
allowed-tools: Task
---
# Intent

Delegate implementation planning to the specialized cm-planner subagent for deep technical analysis and risk-aware planning.

# Procedure

1. **Pass goal to planner**: Provide $ARGUMENTS as the planning objective
2. **Planner analyzes**: Examines codebase, considers options, assesses risks
3. **Structured output**: Planner provides comprehensive plan with:
   - Goal clarification and constraints
   - Current state analysis
   - Multiple options with trade-offs
   - Detailed technical design
   - Step-by-step implementation
   - Risk assessment and mitigations
   - Clear acceptance criteria

# Execution

When this command runs, Claude Code will:

1. Use Task tool to invoke the cm-planner subagent with:
  - subagent_type: "cm-planner"
  - prompt: Pass the planning goal from $ARGUMENTS
  - description: "Create implementation plan"

The cm-planner subagent specializes in:
- Breaking down complex tasks
- Evaluating multiple approaches
- Identifying risks and dependencies
- Creating actionable implementation steps
- Defining clear success criteria

The planner remains read-only during analysis and produces a comprehensive plan that can be saved to `docs/plans/` if desired.
