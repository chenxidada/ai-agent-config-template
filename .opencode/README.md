# .opencode Template Convention

This directory is the shared OpenCode template root.

## Architecture

This template uses an **Orchestrator-driven workflow**. The user interacts with a single primary agent (the Orchestrator), which automatically dispatches work to 10 specialized subagents, collects summaries, and presents conclusions at human confirmation gates.

See `ORCHESTRATOR_ARCHITECTURE.md` at the project root for the full architecture decision document.

## Layout

- `agents/` - Role definitions: 1 orchestrator (primary) + 10 subagents
- `commands/` - Pipeline command triggers (`/feature`, `/bugfix`, `/idea`, `/rebuild`, `/fullflow`, `/analyze`)
- `templates/` - Reusable output templates for each stage
- `snippets/` - Workflow pipeline definitions (referenced by Orchestrator)
- `skills/` - Reusable OpenCode skills
- `hooks/` - Optional automation scripts or hook docs
- `plugins/` - Runtime plugins (kb-sync-runtime)

## Agents

### Orchestrator (primary agent)

- `orchestrator` - Master dispatcher. Receives user input, selects pipeline, dispatches subagents, manages Human Gates, maintains `specs/current-status.md`.

### Subagents (dispatched by Orchestrator via Task tool)

- `repo-explorer` - Repository reconnaissance and reality modeling
- `requirement-analyst` - Requirement clarification and scope convergence
- `program-planner` - Master-spec generation and system-level planning
- `task-planner` - Phase-spec and sub-spec slicing
- `solution-architect` - Technical design and boundary definition
- `implementer` - Implementation within approved boundaries
- `reviewer` - Quality and drift review
- `validator` - Acceptance verification and evidence confirmation
- `knowledge-manager` - Knowledge sync to MCP knowledge base
- `code-analyst` - Deep codebase/module analysis, produces human-readable reports

## Pipeline Commands

| Command | Pipeline | Use Case |
|---------|----------|----------|
| `/feature <desc>` | feature-pipeline | New feature development |
| `/bugfix <desc>` | bugfix-pipeline | Bug investigation and fix |
| `/idea <desc>` | idea-to-mvp | Idea exploration (no implementation) |
| `/rebuild <desc>` | rebuild-knownbase-flow | System rebuild |
| `/fullflow <desc>` | requirements-to-implementation | Full 13-stage workflow |
| `/analyze <desc>` | analyze-pipeline | Codebase/module analysis (human-readable report) |

## Data Flow

- **Downward** (Orchestrator to subagent): Summary (3-5 sentences) + file paths. Subagents read full upstream files themselves from `specs/`.
- **Upward** (subagent to Orchestrator): Summary (3-5 sentences) + output file path + risks/open questions. Full documents never flow back.
- **Persistence**: All subagent outputs go to `specs/` directory. `specs/current-status.md` is the Orchestrator's lifeline after context compression.

## Specs Directory Convention

```
specs/
├── master-spec.md
├── current-status.md
├── exploration/
│   └── repo-exploration.md
├── requirements/
│   └── requirements.md
├── analysis/
│   ├── code-analysis-full.md
│   └── code-analysis-<scope-slug>.md
├── phases/
│   └── <phase-id>/
│       ├── phase-spec.md
│       └── slices/
│           └── <sub-spec-id>/
│               ├── sub-spec.md
│               ├── solution-design.md
│               ├── implementation-summary.md
│               ├── review-report.md
│               └── validation-report.md
└── task-plan/
    └── task-plan.md
```

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

## Spec Sync Model

- Sync `master-spec` to `Projects/<project>/Specs/Master`
- Sync `phase-spec` to `Projects/<project>/Specs/Phases`
- Sync `sub-spec` to `Projects/<project>/Specs/SubSpecs`
- Sync `current-status` to `Projects/<project>/Specs/Status`
- Treat `master-spec` as the primary planning artifact for large projects
