# rebuild-knownbase-flow

Use this workflow when rebuilding, replicating, or iterating a knowledge-base product like Knownbase or similar complex systems. The Orchestrator dispatches each stage via the Task tool.

## Stages

### Stage 1: repo-explorer

- **Dispatch**: Pass the rebuild goal and existing codebase reference
- **Output file**: `specs/exploration/repo-exploration.md`
- **Expect back**: Summary of current codebase, subsystem boundaries, risky integration points

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + feature/product requirement doc reference
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Output file**: `specs/requirements/requirements.md`
- **Expect back**: Summary of true MVP extracted from the product requirement

### Stage 3: task-planner

- **Dispatch**: Pass requirement-analyst summary
- **Read upstream**: `specs/requirements/requirements.md`
- **Output files**: `specs/task-plan/task-plan.md`, `specs/phases/<phase-id>/phase-spec.md`
- **Expect back**: Summary of vertical slices (documents, folders/tags, search, AI chat, RAG, PDF, sync, MCP, etc.)

### Stage 4: solution-architect

- **Dispatch**: Pass task-planner summary + recommended first slice
- **Read upstream**: `specs/phases/<phase-id>/phase-spec.md`
- **Output files**: `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`, `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Expect back**: Summary of architecture proposal, risky subsystems highlighted

### Human Gate 1 (before implementation)

- **Present**: Full plan: MVP scope, slice breakdown, architecture, highlighted risks
- **Wait for**: User confirmation before entering implementation

### Stage 5: knowledge-manager (planning checkpoint)

- **Dispatch**: Pass requirement + architecture summaries (user-confirmed)
- **Action**: Save requirement and architecture milestones
- **Expect back**: Confirmation of sync

### Stage 6: implementer (slice by slice)

- **Dispatch**: Pass solution-architect summary for current slice
- **Read upstream**: `sub-spec.md`, `solution-design.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
- **Expect back**: Summary of changes, deviations, known gaps

### Stage 7: reviewer

- **Dispatch**: Pass implementer summary
- **Read upstream**: `implementation-summary.md`, `sub-spec.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
- **Expect back**: Check for design drift, maintainability, hidden coupling

### Stage 8: validator

- **Dispatch**: Pass implementer summary + reviewer summary
- **Read upstream**: `implementation-summary.md`, `review-report.md`, `sub-spec.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md`
- **Expect back**: Check each slice passes before the next starts

### Stage 9: knowledge-manager (per-slice checkpoint)

- **Dispatch**: Pass slice implementation + validation summaries
- **Action**: Sync key lessons so the rebuild itself becomes documented knowledge
- **Expect back**: Confirmation of sync

### Human Gate 2 (after each slice)

- **Present**: Slice result, validation verdict, recommended next slice
- **Wait for**: User confirmation before starting next slice
- **Repeat**: Stages 6-9 + Human Gate 2 for each slice
