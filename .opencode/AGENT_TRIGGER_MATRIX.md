# Agent Trigger Matrix

## Purpose

This file is a **reference lookup table** for the Orchestrator. It answers two questions:

1. For a given agent, when should it be included or skipped in a pipeline?
2. For a given task type, what is the recommended pipeline sequence?

Pipeline selection logic (which pipeline to use, how to classify user input, short flow vs unified pipeline) lives in `orchestrator.md` -> Interaction Protocol. This file does **not** duplicate that logic.

## Per-Agent Inclusion Rules

### repo-explorer

| Include | Skip |
|---------|------|
| New or unfamiliar repository | Already-explored repo with a very small, known-location change |
| Bug with unclear root cause | |
| Need to assess impact surface | |
| Any non-trivial task (default) | |

### requirement-analyst

| Include | Skip |
|---------|------|
| Any task using the unified pipeline (always) | Short flow (1-2 file obvious fix) |
| Ambiguous or open-ended user need | |
| Need to converge intended scope | |
| Mixed goals/constraints/ideas to untangle | |
| Need explicit acceptance criteria | |

### program-planner

| Include | Skip |
|---------|------|
| Any task using the unified pipeline (always) | Short flow |
| First-time: creates master-spec | Analyze pipeline |
| Append: updates master-spec with new phases | |

### task-planner

| Include | Skip |
|---------|------|
| Any task using the unified pipeline (always) | Short flow |
| Needed to break phase into sub-specs | Analyze pipeline |
| Need to decide execution order | |

### solution-architect

| Include | Skip |
|---------|------|
| Any task using the unified pipeline (always) | Short flow |
| Technical boundary decisions needed | Analyze pipeline |
| Interface, data structure, or integration design | |
| Validation Plan design for downstream agents | |

### implementer

| Include | Skip |
|---------|------|
| Any task that modifies code, config, scripts, or tests (always) | Never skipped when execution is needed |

Note: In the unified pipeline, implementer always has upstream context (sub-spec + solution-design). Must write automated tests for Validation Plan scenarios.

### reviewer

| Include | Skip |
|---------|------|
| Any implementation output (always recommended) | Never fully skipped; may be lightweight for trivial changes |
| Multi-file changes | |
| Structural changes | |
| Scope drift risk | |

### validator

| Include | Skip |
|---------|------|
| Any implementation output (always required) | Never skipped for deliverable work |
| Code, config, or interface behavior changes | |

### knowledge-manager

| Include | Skip |
|---------|------|
| Stable conclusions, decisions, or validated results | Trivial temporary operations with no lasting value |
| Context compression, reset, or handoff (mandatory) | |
| Major workflow checkpoint completed | |

Note: knowledge-manager must execute actual MCP writes. A checkpoint is not complete until sync has run.

### code-analyst

| Include | Skip |
|---------|------|
| User wants to understand an existing codebase or module | User has a change request (use unified pipeline instead) |
| New code/module needs documentation or orientation | User wants implementation planning (use idea pipeline instead) |
| `/analyze` command triggered | |
| Need a human-readable architecture/quality report | |

## Pipeline Sequences by Task Type

### Unified Pipeline (/feature, /bugfix, /rebuild)

```
repo-explorer -> requirement-analyst -> program-planner -> [KM checkpoint] ->
  For each phase:
    task-planner -> solution-architect -> [Human Gate 1] -> [KM checkpoint] ->
    implementer -> reviewer -> validator -> [KM checkpoint] -> [Human Gate 2]
```

All three commands use the same pipeline. Differences are only in the intent context passed to requirement-analyst.

**First-time mode** (no existing master-spec): Creates master-spec from scratch.
**Append mode** (existing master-spec): Updates master-spec, adds new phases.

### Idea Exploration (/idea)

```
repo-explorer -> requirement-analyst -> program-planner -> task-planner -> solution-architect -> knowledge-manager -> [Human Gate]
```

No implementation. Output is analysis and recommendations only. User can proceed to `/feature` or `/rebuild` after review.

### Short Flow (auto-selected)

```
repo-explorer -> implementer -> reviewer -> validator
```

For 1-2 file changes with obvious scope. If repo-explorer reveals larger scope, upgrade to the unified pipeline.

### Codebase Analysis (/analyze)

```
code-analyst -> knowledge-manager
```

Lightweight pipeline for understanding existing code. No Human Gate needed (read-only, no code changes). Supports full repo or scoped analysis.
