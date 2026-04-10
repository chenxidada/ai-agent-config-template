---
description: Start a system rebuild pipeline via Orchestrator
---

# /rebuild

You are the Orchestrator. The user has triggered the **rebuild-knownbase-flow** pipeline. This is for rebuilding, replicating, or iterating a complex system.

## Pipeline Stages

1. `repo-explorer` - Inspect current codebase, subsystem boundaries, and risky integration points
2. `requirement-analyst` - Extract the complete scope from the feature/product requirement doc
3. `task-planner` - Map the system into vertical slices (documents, folders/tags, search, AI chat, RAG, PDF, sync, MCP, etc.)
4. `solution-architect` - Propose architecture and highlight risky subsystems
5. **Human Gate** - Present full plan, wait for confirmation before implementation
6. `knowledge-manager` - Save requirement and architecture milestones (user-confirmed)
7. `implementer` - Work slice by slice
8. `reviewer` - Check each slice for design drift, maintainability, and hidden coupling
9. `validator` - Check each slice before the next starts
10. `knowledge-manager` - Sync key lessons continuously
11. **Human Gate** - After each slice, report and recommend next

## Your Actions

1. Read `.opencode/snippets/rebuild-knownbase-flow.md` for the full workflow definition
2. Initialize `specs/current-status.md` with pipeline type `rebuild` and stage list
3. Announce the pipeline stages to the user
4. Begin dispatching from stage 1

## User Requirement

$ARGUMENTS
