# .opencode Template Convention

This directory is the shared OpenCode template root.

## Architecture

This template uses an **Orchestrator-driven workflow**. The user interacts with a single primary agent (the Orchestrator), which automatically dispatches work to 10 specialized subagents, collects summaries, and presents conclusions at human confirmation gates.

See `ORCHESTRATOR_ARCHITECTURE.md` at the project root for the full architecture decision document.

## Layout

- `agents/` - Role definitions: 1 orchestrator (primary) + 10 subagents
- `commands/` - Pipeline command triggers (`/feature`, `/bugfix`, `/idea`, `/rebuild`, `/analyze`)
- `templates/` - Reusable output templates for each stage
- `snippets/` - Workflow pipeline definitions (referenced by Orchestrator)
- `skills/` - Reusable OpenCode skills
- `hooks/` - Optional automation scripts or hook docs
- `plugins/` - Runtime plugins (kb-sync-runtime)

## System Usage Guide

### How It Works

1. You give the Orchestrator a task (via command or natural language)
2. The Orchestrator selects the appropriate pipeline and dispatches subagents one by one
3. Each subagent reads upstream files from `specs/`, does its work, writes output to `specs/`, and returns a summary
4. At Human Gates, the Orchestrator stops and asks for your confirmation before proceeding
5. All state is persisted in `specs/` — context compression does not lose progress

### Available Commands

| Command | Purpose | What Happens |
|---------|---------|-------------|
| `/feature <desc>` | New feature development | Unified pipeline with requirement-analyst prompt set to "new feature" |
| `/bugfix <desc>` | Bug investigation and fix | Unified pipeline with requirement-analyst prompt set to "bug fix" |
| `/rebuild <desc>` | System rebuild / refactor | Unified pipeline with requirement-analyst prompt set to "rebuild" |
| `/idea <desc>` | Idea exploration (no implementation) | Unified pipeline, stops after solution-architect — planning only |
| `/analyze <desc>` | Codebase / module analysis | Independent flow: code-analyst -> knowledge-manager |
| *(auto-selected)* | Very small, obvious change | Short flow: repo-explorer -> implementer -> reviewer -> validator |

**Key point**: `/feature`, `/bugfix`, and `/rebuild` all use the **same underlying pipeline** (unified-pipeline). The only difference is the context passed to the requirement-analyst. This ensures every change — whether a new feature, a bug fix, or a refactor — goes through the same rigorous process.

### Unified Pipeline Flow

```
User input (/feature or /bugfix or /rebuild)
  |
  |-- Check: does specs/master-spec.md exist?
  |   |-- No  -> First-time mode (create master-spec)
  |   |-- Yes -> Append mode (update master-spec, add new phases)
  |
  v
  repo-explorer -> requirement-analyst -> program-planner
  |
  v  For each new phase (loop):
  |
  |  task-planner -> solution-architect
  |       |
  |       v
  |  [Human Gate 1: confirm design before implementation]
  |       |
  |       v
  |  implementer -> reviewer -> validator
  |       |
  |       v
  |  [KM sync checkpoint]
  |       |
  |       v
  |  [Human Gate 2: confirm result, proceed to next phase]
  |
  v  Next phase...
```

### First Use vs Adding New Requirements

**First time**: You give a feature/bugfix/rebuild description. The system creates `master-spec.md` from scratch, plans phases 1-3, and starts executing phase by phase.

**Adding requirements later**: You input a new `/feature` or `/bugfix` on the same project. The Orchestrator detects the existing `master-spec.md`, enters **append mode**:
- `requirement-analyst` appends new requirements to the existing `requirements.md`
- `program-planner` updates `master-spec.md`, adding new phases (e.g., phase 4-6)
- Execution continues with the new phases

You do not need to manually manage `master-spec.md` or phase numbering.

### Human Gates (Confirmation Points)

- **Gate 1 (before implementation)**: After solution-architect completes the design. You review the technical approach before any code is written.
- **Gate 2 (after each sub-spec)**: After validator confirms the implementation. You review the result before moving to the next slice.

At each gate, you can:
- Reply "continue" to proceed
- Provide feedback or modifications
- Reply "read <file-path>" to inspect a document

### Auto-Retry Mechanism

- If reviewer finds **must-fix** issues -> automatically returns to implementer (max 3 rounds)
- If validator **fails** -> automatically returns to implementer (max 3 rounds)
- If 3 rounds are exceeded -> escalates to you for a decision

### Context Compression Recovery

All state is saved in `specs/current-status.md`. After compression, the Orchestrator automatically reads this file, recovers state, and announces: "Context was compressed. Recovered state. Currently at: <stage>. Continuing."

You do not need to do anything.

## Specs Directory Structure

### Overview

```
specs/
|-- current-status.md                      <- Orchestrator state tracking (compression recovery)
|-- master-spec.md                         <- Project master plan (ALWAYS exists after first run)
|-- exploration/
|   +-- repo-exploration.md               <- repo-explorer: repository analysis report
|-- requirements/
|   +-- requirements.md                   <- requirement-analyst: overall requirements (cumulative)
|-- analysis/                              <- /analyze command output directory
|   +-- code-analysis-<scope>.md          <- code-analyst: analysis report
|-- phases/
    |-- phase-1/
    |   |-- requirements.md               <- program-planner: phase-specific requirements
    |   |-- phase-spec.md                 <- task-planner: task breakdown for this phase
    |   +-- slices/
    |       +-- <sub-spec-id>/
    |           |-- sub-spec.md           <- solution-architect: technical spec + validation plan
    |           |-- solution-design.md    <- solution-architect: detailed design document
    |           |-- implementation-summary.md <- implementer: what was done, deviations, gaps
    |           |-- review-report.md      <- reviewer: code review findings
    |           |-- validation-report.md  <- validator: test execution results
    |           |-- test-scripts/         <- validator: temporary verification scripts (optional)
    |           +-- screenshots/          <- validator: frontend visual validation (optional)
    |-- phase-2/
    |   +-- (same structure)
    +-- phase-3/
        +-- ...
```

### File Producer and Consumer Map

| File | Produced By | Consumed By | Description |
|------|------------|-------------|-------------|
| `current-status.md` | Orchestrator | Orchestrator | State tracking for compression recovery. Users generally don't need to read this. |
| `master-spec.md` | program-planner | task-planner, Orchestrator | Project master plan with all phase definitions. Central control document. |
| `requirements/requirements.md` | requirement-analyst | program-planner | Cumulative overall requirements. New requirements are appended. |
| `phases/<id>/requirements.md` | program-planner | task-planner, solution-architect | Phase-specific requirements extracted from overall requirements. |
| `phases/<id>/phase-spec.md` | task-planner | solution-architect | Task breakdown: sub-spec candidates, build order, dependencies. |
| `sub-spec.md` | solution-architect | implementer, reviewer, validator | Technical spec with acceptance criteria and Validation Plan. |
| `solution-design.md` | solution-architect | implementer, reviewer | Detailed design: entities, APIs, integration strategy. |
| `implementation-summary.md` | implementer | reviewer, validator | What changed, key files, deviations from plan, handoff notes. |
| `review-report.md` | reviewer | validator, implementer (if must-fix) | Code review: logic checks, test coverage, additional test scenarios. |
| `validation-report.md` | validator | Orchestrator, knowledge-manager | Test execution results, pass/fail evidence, acceptance verdict. |

### File Lifecycle

- **`master-spec.md`**: Created on first run, persists and grows incrementally. New requirements add new phases.
- **`requirements/requirements.md`**: Cumulative. Each new requirement input is appended with a timestamp.
- **`phases/` files**: Each phase is independent. Files are not modified after completion (except during reviewer/validator retry loops).

## Agents

### Orchestrator (primary agent)

- `orchestrator` - Master dispatcher. Receives user input, selects pipeline, dispatches subagents, manages Human Gates, maintains `specs/current-status.md`.

### Subagents (dispatched by Orchestrator via Task tool)

- `repo-explorer` - Repository reconnaissance and reality modeling
- `requirement-analyst` - Requirement clarification and scope convergence (supports append mode)
- `program-planner` - Master-spec generation and incremental update, per-phase requirements extraction
- `task-planner` - Phase-spec generation and sub-spec slicing
- `solution-architect` - Technical design, boundary definition, and Validation Plan design
- `implementer` - Implementation within approved boundaries (must write tests)
- `reviewer` - Quality, logic correctness, and test coverage review
- `validator` - Acceptance verification, test execution, and evidence confirmation
- `knowledge-manager` - Knowledge sync to MCP knowledge base
- `code-analyst` - Deep codebase/module analysis, produces human-readable reports

## Pipeline Commands

| Command | Pipeline | Use Case |
|---------|----------|----------|
| `/feature <desc>` | unified-pipeline | New feature development |
| `/bugfix <desc>` | unified-pipeline | Bug investigation and fix |
| `/rebuild <desc>` | unified-pipeline | System rebuild |
| `/idea <desc>` | idea-to-mvp | Idea exploration (no implementation) |
| `/analyze <desc>` | analyze-pipeline | Codebase/module analysis (human-readable report) |

## Data Flow

- **Downward** (Orchestrator to subagent): Summary (3-5 sentences) + file paths. Subagents read full upstream files themselves from `specs/`.
- **Upward** (subagent to Orchestrator): Summary (3-5 sentences) + output file path + risks/open questions. Full documents never flow back.
- **Persistence**: All subagent outputs go to `specs/` directory. `specs/current-status.md` is the Orchestrator's lifeline after context compression.

## Key References

- `ORCHESTRATOR_ARCHITECTURE.md` - Full architecture spec
- `AGENT_ROLE_MATRIX.md` - Consolidated role map (11 roles including orchestrator)
- `AGENT_TRIGGER_MATRIX.md` - Pipeline selection and agent trigger rules
- `snippets/kb-sync-sop.md` - MCP sync procedure
- `hooks/kb-sync-runtime-plugin.md` - Runtime trigger implementation

## Guidelines

- Keep this directory generic and reusable across projects
- Do not hardcode machine-specific absolute paths
- If a file depends on local paths, resolve them through env vars or launcher scripts
- When adding new content, distribute it via `setup.sh`

## Knowledge Sync Model

- Prefer structured knowledge objects over one monolithic project note
- Use `Tasks`, `Topics`, `Decisions`, and `Snapshots` under `Projects/<project>/`
- Use `Daily/<YYYY>/<YYYY-MM>/` for day-based continuity notes

### Trigger Model

- Automatic compression trigger -> create `Snapshot Doc` and update `Daily Digest`
- Automatic workflow checkpoint trigger -> sync the completed stage result immediately
- Manual user trigger -> summarize and sync on explicit request

### Runtime Expectation

- A trigger is only fulfilled if MCP write actions actually ran
- Workflow stages are not fully complete until their required checkpoint sync finishes
- The default runtime plugin is configured in `opencode.jsonc` and implemented in `plugins/kb-sync-runtime.mjs`
