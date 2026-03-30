# bugfix-pipeline

Use this workflow for a debugging and repair task. The Orchestrator dispatches each stage via the Task tool.

## Stages

### Stage 1: repo-explorer

- **Dispatch**: Pass the bug description, error messages, reproduction steps
- **Output file**: `specs/exploration/repo-exploration.md`
- **Expect back**: Summary of failing path, affected modules, likely root-cause area

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + bug description
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Output file**: `specs/requirements/requirements.md`
- **Expect back**: Summary of expected vs actual behavior, root-cause hypothesis, acceptance criteria for the fix

### Stage 3: knowledge-manager (root-cause checkpoint)

- **Dispatch**: Pass requirement-analyst summary (only if durable root-cause framing was reached)
- **Action**: Sync root-cause framing as Topic Doc
- **Expect back**: Confirmation of sync
- **Skip condition**: If the bug is trivial and root-cause is obvious

### Stage 4: task-planner

- **Dispatch**: Pass requirement-analyst summary
- **Read upstream**: `specs/requirements/requirements.md`
- **Output file**: `specs/task-plan/task-plan.md`
- **Expect back**: Summary of smallest safe fix slice

### Human Gate (before implementation)

- **Present**: Root-cause analysis, proposed fix approach, scope of changes
- **Wait for**: User confirmation to proceed, or alternative fix direction

### Stage 5: implementer

- **Dispatch**: Pass task-planner summary + root-cause summary
- **Read upstream**: `specs/requirements/requirements.md`, `specs/task-plan/task-plan.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
- **Expect back**: Summary of minimal repair applied, files changed, deviations

### Stage 6: reviewer

- **Dispatch**: Pass implementer summary
- **Read upstream**: `implementation-summary.md`, `specs/requirements/requirements.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
- **Expect back**: Verdict on whether fix is narrowly scoped, no hidden quality issues

### Stage 7: validator

- **Dispatch**: Pass implementer summary + reviewer summary
- **Read upstream**: `implementation-summary.md`, `review-report.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md`
- **Expect back**: Verification and regression check results

### Stage 8: knowledge-manager (debugging checkpoint)

- **Dispatch**: Pass implementation + validation summaries
- **Action**: Sync root cause, fix, and verification result
- **Expect back**: Confirmation of sync
