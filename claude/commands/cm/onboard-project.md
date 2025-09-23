---
description: >-
  Complete project onboarding workflow combining stack analysis, architecture
  overview, and implementation guidance
argument-hint: '[quick|standard|deep]'
allowed-tools: 'Task, Read'
plan_mode: 'true'
---
# Intent

Provide a comprehensive project onboarding experience by orchestrating multiple specialized subagents to deliver complete project understanding. This meta-command chains stack analysis, repository explanation, and planning guidance for new team members or project exploration.

# Procedure

This command implements a **multi-agent workflow** that combines:

1. **Technology Stack Analysis** → cm-stack-profiler subagent
2. **Repository Architecture Overview** → cm-repo-explainer subagent  
3. **Implementation Planning Guidance** → cm-planner subagent

The workflow adapts based on the analysis mode argument:
- **quick**: Essential overview for immediate productivity
- **standard** (default): Comprehensive analysis with actionable insights
- **deep**: Thorough investigation with detailed recommendations

# Execution

When this command runs, Claude Code will:

## Phase 1: Technology Stack Analysis

Use Task tool to invoke the cm-stack-profiler subagent:
- **subagent_type**: "cm-stack-profiler"
- **description**: "Analyze technology stack for project onboarding"
- **prompt**: 
  ```
  Analyze this project's technology stack for new team member onboarding. 
  Focus on essential technologies, build commands, and development setup.
  Mode: [quick|standard|deep based on $ARGUMENTS]
  
  Provide:
  - Key technologies and versions
  - Essential build/run/test commands
  - Development environment setup
  - Entry points and hot paths
  
  Format for onboarding context - prioritize actionable information.
  ```

## Phase 2: Repository Architecture Overview

Use Task tool to invoke the cm-repo-explainer subagent:
- **subagent_type**: "cm-repo-explainer"
- **description**: "Explain repository architecture for onboarding"
- **prompt**:
  ```
  Provide repository architecture overview for new team member onboarding.
  Mode: [quick|standard|deep based on $ARGUMENTS]
  
  Focus on:
  - Overall purpose and goals
  - Directory structure and organization
  - Key modules and their relationships
  - Critical code paths
  - Quick win opportunities for new contributors
  
  Assume the reader has the technology stack context from previous analysis.
  Format for onboarding - emphasize practical understanding.
  ```

## Phase 3: Implementation Planning Guidance

Use Task tool to invoke the cm-planner subagent:
- **subagent_type**: "cm-planner"
- **description**: "Provide implementation planning guidance for onboarding"
- **prompt**:
  ```
  Based on the technology stack and repository architecture analysis, provide 
  implementation planning guidance for a new team member.
  
  Focus on:
  - Recommended first tasks and areas to explore
  - Development workflow and best practices  
  - Common gotchas and how to avoid them
  - Suggested learning path for project mastery
  - How to contribute effectively
  
  This is the final phase of project onboarding - synthesize insights from 
  stack analysis and architecture overview into actionable guidance.
  Mode: [quick|standard|deep based on $ARGUMENTS]
  ```

## Workflow Integration

The three-phase approach provides:

1. **Foundation Knowledge**: What technologies are used and how to run them
2. **Structural Understanding**: How the codebase is organized and what it does
3. **Practical Guidance**: How to work effectively within this project

Each phase builds on the previous one, creating a comprehensive onboarding experience that combines technical analysis with practical development guidance.

## Analysis Modes

### Quick Mode
- Essential stack overview (key technologies, basic commands)
- High-level architecture (purpose, main directories)
- Immediate next steps (how to get started contributing)

### Standard Mode (Default)
- Complete stack analysis with optimization recommendations
- Detailed architecture with patterns and relationships
- Comprehensive development guidance with best practices

### Deep Mode  
- Exhaustive technology analysis with alternatives and rationale
- In-depth architectural investigation with improvement opportunities
- Advanced planning guidance with project mastery roadmap

The onboarding workflow scales from "productive in 1 hour" to "expert in the project" based on the selected analysis depth.

## Best Practices

This meta-command demonstrates **command composition patterns** for Context Monkey:
- Sequential agent execution with context building
- Argument passing through workflow phases
- Consistent output formatting across agents
- Scalable analysis depth based on user needs

Each subagent receives context about its role in the broader workflow to ensure cohesive, complementary analysis rather than redundant information.
