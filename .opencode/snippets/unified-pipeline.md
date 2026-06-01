# Unified Pipeline

This is the standard pipeline for all development workflows: `/feature`, `/bugfix`, and `/rebuild`. The Orchestrator dispatches each stage via the Task tool.

The only difference between `/feature`, `/bugfix`, and `/rebuild` is the context passed to the requirement-analyst (describing the nature of the change). The pipeline structure is identical.

## Design Document as Authoritative Source

When the user provides a completed design document as input (rather than a raw idea), the design document becomes the **authoritative source** for all interface definitions, constraints, and acceptance criteria. ALL downstream agents MUST read the original design document directly — not just the intermediate specs/ artifacts.

The Orchestrator MUST pass the design document path to every agent dispatch. Agents MUST read it in full when they need interface definitions, struct layouts, performance targets, or design decisions.

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
- **Expect back**: Output file path

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + user's requirement description
- **Mode context**:
  - `/feature`: "Analyze this new feature requirement"
  - `/bugfix`: "Analyze this bug — identify root cause, affected areas, and fix approach"
  - `/rebuild`: "Analyze this rebuild/refactor requirement — assess impact scope"
  - First-time from idea: "Create a new requirements document" (create mode)
  - First-time from design doc: "Extract implementable requirements from this completed design document" (extract mode)
  - Append: "Append new requirements to the existing `specs/requirements/requirements.md`" (append mode)
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Read original design document**: (path provided by Orchestrator; read in full — see §Design Document as Authoritative Source)
- **Read existing** (append mode): `specs/requirements/requirements.md`
- **Output file**: `specs/requirements/requirements.md`
- **Expect back**: Output file path

### Stage 3: program-planner

- **Dispatch**: Pass requirement-analyst summary + user decisions on open questions
- **Mode context**:
  - First-time: "Create a new master-spec with phase breakdown"
  - Append: "Update the existing `specs/master-spec.md` — add new phases for the new requirements. Do NOT modify completed phases."
- **Read upstream**: `specs/requirements/requirements.md`, `specs/exploration/repo-exploration.md` (if available)
- **Read original design document**: (path provided by Orchestrator; read in full — see §Design Document as Authoritative Source)
- **Read existing** (append mode): `specs/master-spec.md`
- **Output files**:
  - `specs/master-spec.md` (create or update)
  - `specs/phases/<phase-id>/requirements.md` (one per new phase — phase-specific requirements with module contracts)
- **Expect back**: Output file path

### Stage 4: knowledge-manager checkpoint

- **Dispatch**: Pass requirement + planning summaries
- **Action**: Sync requirement and architecture milestones as Topic Doc and/or Decision Doc
- **Expect back**: Output file path

---

**The following stages repeat for each phase in the master-spec:**

---

### Phase Entry Gate (NEW — before Stage 4.5, Phase 2+ only)

Before Phase Preparation for Phase N (N >= 2), the Orchestrator MUST:

1. Read `specs/tech-debt-registry.md` §活跃债务
2. Filter entries where target phase = N or blocking = 🔴
3. Present inherited debt to user at a Human Gate:
   ```
   Phase N inherits the following technical debt (X items):
   - [ID] description — current behavior → expected, target Phase N
   Are these included in Phase N's plan?
   ```
4. User must confirm before proceeding to Stage 4.5

---

### Stage 4.5: Phase Preparation — repo-explorer (per phase)

- **code2prompt**: The repo-explorer may use the code2prompt tool (see `.opencode/skills/code2prompt/SKILL.md`) to generate a structured file index before deep exploration.

See `orchestrator.md` §"Phase Preparation" for dispatch instructions.
- **Output file**: `specs/phases/<phase-id>/repo-exploration.md`

### Stage 4.6: Phase Preparation — code-analyst (per phase, OPTIONAL)

See `orchestrator.md` §"Phase Preparation" for dispatch instructions.
- **Output file**: `specs/phases/<phase-id>/code-analysis.md`

---

### Stage 5: task-planner (per phase)

- **Dispatch**: Pass program-planner summary + which phase to plan
- **Read upstream**:
  - `specs/master-spec.md`
  - `specs/phases/<phase-id>/requirements.md`
  - **Original design document** (path provided by Orchestrator; read in full — see §Design Document as Authoritative Source)
  - `specs/tech-debt-registry.md` — inherited technical debt from previous phases
  - `specs/current-status.md` — Phase Deferred Items Tracker
  - Previous phases' `scope-gap-report.md` (path provided by Orchestrator)
- **Output file**: `specs/phases/<phase-id>/phase-spec.md`
- **Expect back**: Output file path

### Stage 6: solution-architect (per slice)

- **Dispatch**: Pass task-planner summary + which sub-spec to design
- **Read upstream**:
  - `specs/phases/<phase-id>/phase-spec.md`
  - `specs/phases/<phase-id>/requirements.md`
  - **Original design document** (path provided by Orchestrator; read in full — see §Design Document as Authoritative Source)
  - `specs/tech-debt-registry.md` — verify dependency interfaces are not known stubs
- **Output files**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Expect back**: Output file path

### Human Gate 1 (before implementation)

- **Present**: Phase plan + technical design summary for the current sub-spec
- **Purpose**: User confirms the approach before any code is written
- **User can**: Continue, modify, or request to read specific files

### Stage 7: knowledge-manager checkpoint

- **Dispatch**: Pass design decision summary
- **Action**: Sync architecture/design decisions as Decision Doc
- **Expect back**: Output file path

### Stage 8: implementer (per slice)

- **Dispatch**: Pass solution-architect summary
- **Read upstream**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
  - **Original design document** (path provided by Orchestrator; read in full — see §Design Document as Authoritative Source)
  - `specs/tech-debt-registry.md` — check which interfaces are known stubs before depending on them
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
- **Code changes**: Actual code modifications + automated tests for Validation Plan scenarios
- **Expect back**: Output file path

### Stage 9: reviewer (per slice)

- **Dispatch**: Pass implementer summary
- **Read upstream**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
  - **Original design document** (path provided by Orchestrator; read in full — see §Design Document as Authoritative Source)
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
- **Expect back**: Verdict (pass/must-fix/should-fix) + output file path
- **Amendment Tracking**: After approving deviations, reviewer updates sub-spec.md and solution-design.md Amendments sections
- **Loop**: If must-fix -> auto-dispatch implementer to fix -> re-review (max 3 rounds)
- **Stub Detection**: Reviews code for unregistered stubs using detection signals (empty bodies, hardcoded returns, one-way #ifdef). Known stubs confirmed; unknown stubs flagged as must-fix.

### Stage 10: validator (per slice)

- **Dispatch**: Pass implementer + reviewer summaries
- **Amendment Awareness**: Reads sub-spec.md Amendments section before building Test Execution Matrix — test scenarios affected by approved amendments use amended criteria
- **Read upstream**:
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md`
  - `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`
  - **Original design document** (path provided by Orchestrator; read in full — see §Design Document as Authoritative Source)
- **Output file**: `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md`
- **Expect back**: Verdict (pass/partial/fail) + output file path
- **Loop**: If fail → dispatch `code-analyst` (diagnosis mode: read validation-report + relevant code → produce failure diagnosis to `specs/phases/<phase-id>/slices/<sub-spec-id>/failure-diagnosis.md`) → dispatch `implementer` with diagnosis to fix → re-dispatch `validator`. Max 3 rounds total.
- **Stub-Aware Validation**: Reads tech-debt-registry.md — known stubs excluded from behavioral checks. Unregistered critical-path functions subjected to parameter variation tests.

### Stage 11: knowledge-manager checkpoint

- **Dispatch**: Pass implementation + validation summaries
- **Action**: Sync implementation result as Task Doc
- **Expect back**: Output file path

### Human Gate 2 (sub-spec completion)

- **Present**: Sub-spec result summary — what was implemented, review findings, validation result
- **Purpose**: User confirms the sub-spec is complete
- **Next**: If more sub-specs in the current phase, return to Stage 6. If phase is complete and more phases exist, return to Stage 5.

### Phase Closure (after all SS in a Phase complete)

When all sub-specs in a Phase have passed validator, the Orchestrator executes the Phase Closure Protocol.
See `orchestrator.md` §"Phase Closure Protocol" for the full procedure.

**Phase Closure steps include**:
5. Sync deferred items from scope-gap-report to `specs/tech-debt-registry.md`

**After Phase Closure and before the next Phase's task-planner**, the Phase Preparation stages run: repo-explorer (Stage 4.5) to re-explore the now-modified codebase, and optionally code-analyst (Stage 4.6) to re-analyze. This ensures the next phase starts with fresh knowledge of the current codebase state.

---

## Loop Counter Reset

When moving from one sub-spec to the next, or from one phase to the next, the reviewer/validator loop counters reset to 0.

## Loop Document Append Mode

In reviewer must-fix or validator fail loops, `implementation-summary.md`, `review-report.md`, and `validation-report.md` use **APPEND mode** (timestamped rounds) rather than OVERWRITE mode. This preserves the history of what was tried and why across all loop cycles.

## Expected Output Structure

After a complete run, the specs/ directory will contain:

```
specs/
|-- tech-debt-registry.md              ← unified tech debt registry (NEW)
|-- current-status.md
|-- master-spec.md
|-- exploration/
|   +-- repo-exploration.md          ← first-time exploration only
|-- requirements/
|   +-- requirements.md
+-- phases/
    |-- <phase-1>/
    |   |-- repo-exploration.md       ← phase-specific (NEW)
    |   |-- code-analysis.md          ← phase-specific, optional (NEW)
    |   |-- requirements.md
    |   |-- phase-spec.md
    |   |-- scope-gap-report.md
    |   +-- slices/
    |       +-- <sub-spec-id>/
    |           |-- sub-spec.md
    |           |-- solution-design.md
    |           |-- implementation-summary.md
    |           |-- review-report.md
    |           +-- validation-report.md
    |-- <phase-2>/
    |   |-- repo-exploration.md       ← re-explored for this phase (NEW)
    |   |-- code-analysis.md          ← re-analyzed for this phase (NEW)
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
