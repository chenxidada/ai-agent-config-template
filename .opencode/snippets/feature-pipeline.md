# feature-pipeline

Use this workflow for a new feature implementation. The Orchestrator dispatches each stage via the Task tool.

## Stages

### Stage 1: repo-explorer

- **Dispatch**: Pass the user's feature description
- **Output file**: `specs/exploration/repo-exploration.md`
- **Expect back**: Summary of relevant modules, entry points, impact surface, risks

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + user requirement
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Output file**: `specs/requirements/requirements.md`
- **Expect back**: Summary of MVP scope, acceptance criteria count, open questions

### Stage 3: knowledge-manager (requirement checkpoint)

- **Dispatch**: Pass requirement-analyst summary
- **Action**: Sync requirement as Topic Doc or Decision Doc
- **Expect back**: Confirmation of sync

### Stage 4: task-planner

- **Dispatch**: Pass requirement-analyst summary + user decisions on open questions
- **Read upstream**: `specs/requirements/requirements.md`
- **Output file**: `specs/phases/<phase-id>/phase-spec.md`, `specs/task-plan/task-plan.md`
- **Expect back**: Summary of slices, recommended first slice

### Stage 5: solution-architect (if needed)

- **Dispatch**: Pass task-planner summary + recommended sub-spec
- **Read upstream**: `specs/phases/<phase-id>/phase-spec.md`
- **Output files**: `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`, `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Expect back**: Summary of technical approach, key decisions, risks
- **Skip condition**: If the slice is trivially simple and the user agrees

### Human Gate 1 (before implementation)

- **Present**: Stage progress table, key conclusions from stages 1-5, open risks
- **Wait for**: User confirmation to proceed, or modifications

### Stage 6: knowledge-manager (planning checkpoint)

- **Dispatch**: Pass planning/architecture summaries (user-confirmed)
- **Action**: Sync plan and architecture as Decision Doc
- **Expect back**: Confirmation of sync

### Stage 7: implementer

- **Dispatch**: Pass solution-architect summary (or task-planner summary if architect was skipped)
- **Read upstream**: `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`, `solution-design.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
- **Expect back**: Summary of changes made, deviations, known gaps

### Stage 8: reviewer

- **Dispatch**: Pass implementer summary
- **Read upstream**: `implementation-summary.md`, `sub-spec.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
- **Expect back**: Verdict (pass/must-fix/should-fix), issue count, key concerns

### Stage 9: validator

- **Dispatch**: Pass implementer summary + reviewer summary
- **Read upstream**: `implementation-summary.md`, `review-report.md`, `sub-spec.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md`
- **Expect back**: Verdict (pass/partial/fail), criteria met count, failing items

### Stage 10: knowledge-manager (implementation checkpoint)

- **Dispatch**: Pass implementation + validation summaries
- **Action**: Sync implementation result, update task record and current-status
- **Expect back**: Confirmation of sync

### Human Gate 2 (after slice completion)

- **Present**: Slice result summary, validation verdict, recommended next slice
- **Wait for**: User confirmation to proceed to next slice or stop
