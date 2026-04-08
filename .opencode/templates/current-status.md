# Current Status

## Pipeline

<!-- Pipeline type: feature | bugfix | idea | rebuild | fullflow -->
<!-- User requirement (1-2 sentences) -->

## Stage Progress

<!-- Orchestrator updates this table after every stage completion -->

| # | Stage | Agent | Status | Output File | Summary |
|---|-------|-------|--------|-------------|---------|

<!-- Status values: pending | in_progress | completed | skipped | failed -->

## Current Stage

<!-- Which stage is actively running or next to run -->

## Recovery Briefing

<!-- CRITICAL: This section is the primary recovery source after context compression. -->
<!-- Keep it current after EVERY stage completion. -->

<!-- Current sub-spec file: specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md -->
<!-- Last agent output file: <path to the last completed agent's output file> -->
<!-- Next agent to dispatch: <agent name> -->
<!-- Info to pass downstream: <1-2 sentence summary for the next agent> -->

## Knowledge Sync Checkpoints

<!-- Track whether each mandatory KM checkpoint has been executed -->

| Checkpoint | Required At | Status | Sync Result |
|------------|-------------|--------|-------------|
<!-- Example rows:
| Requirement | After stage 2 | completed | Topic Doc synced |
| Planning | After HG1 | pending | — |
| Implementation | After stage 9 | pending | — |
-->

## User Decisions

<!-- Key decisions the user made at Human Gates or during intervention -->

## Open Questions

<!-- Unresolved items that need user input -->

## Loop Tracking

<!-- Track reviewer/validator retry loops -->
<!-- Format: reviewer round 1/3, validator round 0/3 -->

<!-- Track code-analyst resume cycles for large codebase analysis -->
<!-- Format: code-analyst resume 2/5 -->

## Analysis Recovery State

<!-- Only populated during analyze pipeline with incremental analysis -->
<!-- 
- Progress file: specs/analysis/.analysis-progress.json
- Completion: 5/12 modules (~40%)
- Last module: src/services/
- Resume count: 2/5
-->

## Last Human Gate

<!-- What was presented, what the user decided -->

## Recommended Next Step

<!-- What the Orchestrator plans to do next -->
