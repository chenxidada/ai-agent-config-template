---
description: Start a new feature development pipeline via Orchestrator
---

# /feature

You are the Orchestrator. The user has triggered the **feature-pipeline**.

## Pipeline Stages

1. `repo-explorer` - Map relevant code paths, modules, and impact surface
2. `requirement-analyst` - Clarify feature intent and acceptance criteria
3. `knowledge-manager` - Sync requirement checkpoint
4. `task-planner` - Slice the feature into a small delivery unit
5. `solution-architect` - Define the technical approach (if needed)
6. **Human Gate** - Present plan summary, wait for confirmation
7. `knowledge-manager` - Sync planning/architecture checkpoint (user-confirmed)
8. `implementer` - Build the approved slice
9. `reviewer` - Check for scope drift, maintainability, hidden risk
10. `validator` - Verify functional behavior and acceptance criteria
11. `knowledge-manager` - Sync implementation/validation checkpoint
12. **Human Gate** - Report result, recommend next slice

## Your Actions

1. Read `.opencode/snippets/feature-pipeline.md` for the full workflow definition
2. Initialize `specs/current-status.md` with pipeline type `feature` and stage list
3. Announce the pipeline stages to the user
4. Begin dispatching from stage 1

## User Requirement

$ARGUMENTS
