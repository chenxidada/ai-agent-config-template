# Agent Trigger Matrix

## Purpose

This file is a **reference lookup table** for the Orchestrator. It answers two questions:

1. For a given agent, when should it be included or skipped in a pipeline?
2. For a given task type, what is the recommended pipeline sequence?

Pipeline selection logic (which pipeline to use, how to classify user input, short flow vs full flow) lives in `orchestrator.md` → Interaction Protocol. This file does **not** duplicate that logic.

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
| Ambiguous or open-ended user need | Clear engineering directive ("fix this error", "add this field") |
| Need to converge MVP scope | Single-point change with obvious acceptance criteria |
| Mixed goals/constraints/ideas to untangle | |
| Need explicit acceptance criteria | |

### program-planner

| Include | Skip |
|---------|------|
| System-level or product-level rebuild | Normal feature work |
| Cross-domain task (frontend + backend + infra) | Small bug fix |
| Need phased master-spec with repeated confirmation | Single-slice iteration |
| Module decomposition required | |

### task-planner

| Include | Skip |
|---------|------|
| Task needs slicing into sub-specs | Single small fix |
| Multiple phases or sub-modules | Single clear minimal feature point |
| Need to decide execution order | |
| Need to reduce one-shot implementation risk | |

### solution-architect

| Include | Skip |
|---------|------|
| Technical boundary decisions needed | Non-structural small fix |
| Interface, data structure, or integration design | Implementation path already obvious and low-risk |
| Multiple viable approaches to evaluate | |
| Gap between current codebase and target state | |

### implementer

| Include | Skip |
|---------|------|
| Any task that modifies code, config, scripts, or tests (always) | Never skipped when execution is needed |

Note: In complex pipelines, implementer should not run without upstream context (exploration, requirements, design).

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

## Pipeline Sequences by Task Type

### New Feature (/feature)

```
repo-explorer → requirement-analyst → task-planner → solution-architect → [Human Gate] → implementer → reviewer → validator → knowledge-manager → [Human Gate]
```

If system-level, upgrade to `/fullflow` (adds `program-planner` before `task-planner`).

### Bug Fix (/bugfix)

```
repo-explorer → requirement-analyst → task-planner → [Human Gate] → implementer → reviewer → validator → knowledge-manager
```

If root cause is already clear and fix is small, downgrade to short flow.

### Idea Exploration (/idea)

```
repo-explorer → requirement-analyst → task-planner → solution-architect → knowledge-manager → [Human Gate]
```

No implementation. Output is analysis and recommendations only.

### System Rebuild (/rebuild)

```
repo-explorer → requirement-analyst → program-planner → task-planner → solution-architect → [Human Gate] → implementer → reviewer → validator → knowledge-manager → [Human Gate]
```

Full flow. Do not skip `program-planner`, `reviewer`, or `validator`. Human Gate after each slice.

### Full Flow (/fullflow)

```
repo-explorer → requirement-analyst → program-planner → task-planner → solution-architect → [Human Gate] → implementer → reviewer → validator → knowledge-manager → [Human Gate]
```

Complete 13-stage pipeline for large or unclear tasks.

### Short Flow (auto-selected)

```
repo-explorer → implementer → reviewer → validator
```

For 1-2 file changes with obvious scope. If repo-explorer reveals larger scope, upgrade to a full pipeline.
