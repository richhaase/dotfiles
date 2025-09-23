---
description: Delegate to cm-researcher subagent for comprehensive topic investigation
argument-hint: '[topic]'
allowed-tools: Task
plan_mode: 'true'
---
# Intent

Delegate deep research to the specialized cm-researcher subagent for thorough topic investigation combining codebase analysis with external research.

# Procedure

1. **Invoke researcher**: Pass research topic from $ARGUMENTS
2. **Researcher investigates**: Combines repository context with external sources
3. **Comprehensive output**: Researcher provides:
   - Key findings with evidence
   - Detailed analysis and insights
   - Code patterns and implementations
   - External research and best practices
   - Actionable recommendations
   - Areas for further investigation

# Execution

When this command runs, Claude Code will:

1. Use Task tool to invoke the cm-researcher subagent with:
  - subagent_type: "cm-researcher"
  - prompt: Request deep research on topic from $ARGUMENTS
  - description: "Conduct deep research investigation"

The cm-researcher subagent specializes in:
- Systematic investigation methodology
- Combining internal and external sources
- Pattern recognition and analysis
- Evidence-based conclusions
- Structured findings presentation
- Citation and reference management

The researcher provides thorough, well-documented insights that combine local context with broader knowledge.
