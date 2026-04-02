# requirements-to-implementation-workflow

Use this as the master controller workflow from product idea or requirement document to validated implementation. This is the most comprehensive pipeline with all 13 stages. The Orchestrator dispatches each stage via the Task tool.

## Stages

### Stage 1: repo-explorer

- **Dispatch**: Pass the user's requirement or product idea
- **Output file**: `specs/exploration/repo-exploration.md`
- **Template**: `templates/repo-exploration-output.md`
- **Expect back**: Summary of relevant repository areas, modules, constraints

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + user requirement
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Output file**: `specs/requirements/requirements.md`
- **Template**: `templates/requirements-output.md`
- **Expect back**: Summary of scope, MVP, functional areas, requirement structure

### Stage 3: knowledge-manager (requirement checkpoint)

- **Dispatch**: Pass requirement-analyst summary
- **Action**: Sync clarified requirement as Topic Doc or Decision Doc
- **Expect back**: Confirmation of sync

### Stage 4: program-planner

- **Dispatch**: Pass requirement-analyst summary + user decisions
- **Read upstream**: `specs/requirements/requirements.md`, `specs/exploration/repo-exploration.md`
- **Output file**: `specs/master-spec.md`
- **Template**: `templates/master-spec.md`
- **Expect back**: Summary of top-level modules, phases, dependencies, recommended starting phase

### Stage 5: task-planner

- **Dispatch**: Pass program-planner summary + requirement summary
- **Read upstream**: `specs/master-spec.md`, `specs/requirements/requirements.md`
- **Output files**: `specs/phases/<phase-id>/phase-spec.md`, `specs/task-plan/task-plan.md`
- **Templates**: `templates/phase-spec.md`, `templates/task-plan-output.md`
- **Expect back**: Summary of current phase, ordered sub-spec candidates, recommended first sub-spec

### Stage 6: solution-architect

- **Dispatch**: Pass task-planner summary + recommended sub-spec
- **Read upstream**: `specs/phases/<phase-id>/phase-spec.md`
- **Output files**: `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`, `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Templates**: `templates/sub-spec.md`, `templates/solution-design-output.md`
- **Expect back**: Summary of technical design, key decisions, risks, constraints

### Human Gate 1 (before implementation)

- **Present**: master-spec summary, phase-spec summary, current sub-spec summary, key decisions, risks
- **Condition**: Do not enter implementation until sub-spec is explicitly confirmed
- **Wait for**: User confirmation, modifications, or "read <file>" requests

### Stage 7: knowledge-manager (planning checkpoint)

- **Dispatch**: Pass planning + architecture summaries
- **Action**: Sync plan and architecture milestones as Decision Doc and Topic Doc
- **Expect back**: Confirmation of sync

### Stage 8: implementer

- **Dispatch**: Pass solution-architect summary
- **Read upstream**: `sub-spec.md`, `solution-design.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
- **Template**: `templates/implementation-summary.md`
- **Expect back**: Summary of changes, deviations from spec, known gaps, verification notes

### Stage 9: reviewer

- **Dispatch**: Pass implementer summary
- **Read upstream**: `implementation-summary.md`, `sub-spec.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
- **Template**: `templates/review-report.md`
- **Expect back**: Verdict (pass/must-fix/should-fix), issue summary

### Stage 10: validator

- **Dispatch**: Pass implementer summary + reviewer summary
- **Read upstream**: `implementation-summary.md`, `review-report.md`, `sub-spec.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md`
- **Template**: `templates/validation-report.md`
- **Expect back**: Verdict (pass/partial/fail), criteria met, failing items

### Stage 11: knowledge-manager (implementation checkpoint)

**MANDATORY — Do NOT skip this stage**

- **Dispatch**: Pass implementation + validation summaries
- **Include**: `project: ai-agent-config-template` (from `.opencode/project-config.md`)
- **Read**: `implementation-summary.md`, `validation-report.md`
- **Action**: Sync implementation and validation outcome as Task Doc, update Daily Digest if active
- **Expect back**: Confirmation of sync (success/failure, which objects were written)

### Human Gate 2 (after sub-spec completion)

- **Present**: Sub-spec result, validation verdict, recommended next sub-spec
- **Wait for**: User confirmation to start next sub-spec, or stop
- **Repeat**: Stages 6-11 + Human Gate 2 for each subsequent sub-spec

## Stage Gates

- Do not enter implementation before master-spec, current phase-spec, and current sub-spec are complete and confirmed
- Do not enter validation before review is complete unless intentionally using a shortened flow
- Do not skip validation after implementation

Loop handling, knowledge-manager checkpoint gates, escalation rules, and should-fix/partial-pass handling are defined in `orchestrator.md` and apply to all pipelines.

## Standard Outputs

- `specs/exploration/repo-exploration.md`
- `specs/requirements/requirements.md`
- `specs/master-spec.md`
- `specs/phases/<phase-id>/phase-spec.md`
- `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
- `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
- `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
- `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md`
- `specs/current-status.md`
- Knowledge base records

## Good Fit

- greenfield product development
- rebuilding a difficult product with stronger process control
- long-context work that requires repeated user confirmation before implementation
- practicing a spec-driven OpenCode workflow
