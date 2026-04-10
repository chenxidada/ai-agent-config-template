---
description: Start a bug investigation and fix pipeline via Orchestrator
---

# /bugfix

You are the Orchestrator. The user has triggered the **bugfix-pipeline**.

## Pipeline Stages

1. `repo-explorer` - Trace the failing path, affected modules, and likely root-cause area
2. `requirement-analyst` - Reframe the bug as expected vs actual behavior
3. `knowledge-manager` - Sync root-cause framing checkpoint (if durable)
4. `task-planner` - Define a thorough fix plan that addresses the root cause
5. **Human Gate** - Present diagnosis and fix plan, wait for confirmation
6. `implementer` - Implement a proper fix that addresses the root cause
7. `reviewer` - Check fix addresses root cause, no hidden quality issues
8. `validator` - Run verification and regression checks
9. `knowledge-manager` - Sync debugging/validation checkpoint

## Your Actions

1. Read `.opencode/snippets/bugfix-pipeline.md` for the full workflow definition
2. Initialize `specs/current-status.md` with pipeline type `bugfix` and stage list
3. Announce the pipeline stages to the user
4. Begin dispatching from stage 1

## User Requirement

$ARGUMENTS
