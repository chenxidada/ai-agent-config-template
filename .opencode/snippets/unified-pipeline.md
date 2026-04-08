# Unified Pipeline

This is the standard pipeline for all development workflows: `/feature`, `/bugfix`, and `/rebuild`. The Orchestrator dispatches each stage via the Task tool.

The only difference between `/feature`, `/bugfix`, and `/rebuild` is the context passed to the requirement-analyst (describing the nature of the change). The pipeline structure is identical.

## Pipeline Modes

### First-Time Mode

When `specs/master-spec.md` does **not** exist, this is a new project. The full pipeline creates all planning documents from scratch.

### Append Mode

When `specs/master-spec.md` **already exists**, the user is adding new requirements to an ongoing project. The pipeline updates existing documents and adds new phases.

The Orchestrator detects the mode automatically by checking for `specs/master-spec.md`.

## Stages

### Stage 1: repo-explorer

- **Dispatch**: Pass the user's requirement description and any existing system context
- **Output file**: `specs/exploration/repo-exploration.md`
- **Expect back**: Summary of relevant repository areas, constraints, and risks

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + user's requirement description
- **Mode context**:
  - `/feature`: "Analyze this new feature requirement"
  - `/bugfix`: "Analyze this bug — identify root cause, affected areas, and fix approach"
  - `/rebuild`: "Analyze this rebuild/refactor requirement — assess impact scope"
  - First-time: "Create a new requirements document"
  - Append: "Append new requirements to the existing `specs/requirements/requirements.md`"
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Read existing** (append mode): `specs/requirements/requirements.md`
- **Output file**: `specs/requirements/requirements.md`
- **Expect back**: Summary of goals, MVP scope, acceptance criteria, open questions

### Stage 3: program-planner

- **Dispatch**: Pass requirement-analyst summary + user decisions on open questions
- **Mode context**:
  - First-time: "Create a new master-spec with phase breakdown"
  - Append: "Update the existing `specs/master-spec.md` — add new phases for the new requirements. Do NOT modify completed phases."
- **Read upstream**: `specs/requirements/requirements.md`, `specs/exploration/repo-exploration.md` (if available)
- **Read existing** (append mode): `specs/master-spec.md`
- **Output files**:
  - `specs/master-spec.md` (create or update)
  - `specs/phases/<phase-id>/requirements.md` (one per new phase — phase-specific requirements extracted from overall requirements)
- **Expect back**: Summary of modules, number of phases, recommended starting phase, critical dependencies

### Stage 4: knowledge-manager checkpoint

- **Dispatch**: Pass requirement + planning summaries
- **Action**: Sync requirement and architecture milestones as Topic Doc and/or Decision Doc
- **Expect back**: Confirmation of sync

---

**The following stages repeat for each phase in the master-spec:**

---

### Stage 5: task-planner (per phase)

- **Dispatch**: Pass program-planner summary + which phase to plan
- **Read upstream**:
  - `specs/master-spec.md`
  - `specs/phases/<phase-id>/requirements.md`
- **Output file**: `specs/phases/<phase-id>/phase-spec.md`
- **Expect back**: Summary of sub-specs, recommended first sub-spec, dependencies within the phase

### Stage 6: solution-architect (per slice)

- **Dispatch**: Pass task-planner summary + which sub-spec to design
- **Read upstream**:
  - `specs/phases/<phase-id>/phase-spec.md`
  - `specs/phases/<phase-id>/requirements.md`
- **Output files**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Expect back**: Summary of technical design, key decisions, validation plan overview

### Human Gate 1 (before implementation)

- **Present**: Phase plan + technical design summary for the current sub-spec
- **Purpose**: User confirms the approach before any code is written
- **User can**: Continue, modify, or request to read specific files

### Stage 7: knowledge-manager checkpoint

- **Dispatch**: Pass design decision summary
- **Action**: Sync architecture/design decisions as Decision Doc
- **Expect back**: Confirmation of sync

### Stage 8: implementer (per slice)

- **Dispatch**: Pass solution-architect summary
- **Read upstream**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
- **Code changes**: Actual code modifications + automated tests for Validation Plan scenarios
- **Expect back**: Summary of what was implemented, key files changed, deviations from plan

### Stage 9: reviewer (per slice)

- **Dispatch**: Pass implementer summary
- **Read upstream**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
- **Expect back**: Overall verdict (pass/must-fix/should-fix), finding counts, test coverage assessment
- **Loop**: If must-fix -> auto-dispatch implementer to fix -> re-review (max 3 rounds)

### Stage 10: validator (per slice)

- **Dispatch**: Pass implementer + reviewer summaries
- **Read upstream**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md`
- **Expect back**: Overall result (pass/partial/fail), scenarios tested, pass/fail counts
- **Loop**: If fail -> auto-dispatch implementer to fix -> re-validate (max 3 rounds)

### Stage 11: knowledge-manager checkpoint

- **Dispatch**: Pass implementation + validation summaries
- **Action**: Sync implementation result as Task Doc
- **Expect back**: Confirmation of sync

### Human Gate 2 (sub-spec completion)

- **Present**: Sub-spec result summary — what was implemented, review findings, validation result
- **Purpose**: User confirms the sub-spec is complete
- **Next**: If more sub-specs in the current phase, return to Stage 6. If phase is complete and more phases exist, return to Stage 5.

---

## Loop Counter Reset

When moving from one sub-spec to the next, or from one phase to the next, the reviewer/validator loop counters reset to 0.

## Expected Output Structure

After a complete run, the specs/ directory will contain:

```
specs/
|-- current-status.md
|-- master-spec.md
|-- exploration/
|   +-- repo-exploration.md
|-- requirements/
|   +-- requirements.md
+-- phases/
    |-- <phase-1>/
    |   |-- requirements.md
    |   |-- phase-spec.md
    |   +-- slices/
    |       +-- <sub-spec-id>/
    |           |-- sub-spec.md
    |           |-- solution-design.md
    |           |-- implementation-summary.md
    |           |-- review-report.md
    |           +-- validation-report.md
    |-- <phase-2>/
    |   +-- ...
    +-- ...
```

## Phase ID Convention

Use kebab-case derived from the phase name. Examples:
- `phase-1-user-auth`
- `phase-2-data-export`
- `phase-3-dashboard`

## Sub-Spec ID Convention

Use kebab-case derived from the sub-spec name. Examples:
- `login-flow`
- `csv-export`
- `chart-component`
