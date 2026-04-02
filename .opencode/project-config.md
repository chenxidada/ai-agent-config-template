# Project Configuration

## Purpose

This file defines project-level constants used by all agents and sync operations. It ensures consistency in naming across the knowledge base.

## Project Identity

| Key | Value |
|-----|-------|
| **project** | `ai-agent-config-template` |
| **display_name** | AI Agent 配置模板 |
| **kb_root** | `Projects/ai-agent-config-template` |

## How To Use

### For knowledge-manager

When syncing to the knowledge base, always use:

```
Projects/ai-agent-config-template/Tasks/
Projects/ai-agent-config-template/Topics/
Projects/ai-agent-config-template/Decisions/
Projects/ai-agent-config-template/Snapshots/
```

### For Daily Digest

Use:

```
Daily/<YYYY>/<YYYY-MM>/[daily] YYYY-MM-DD - ai-agent-config-template
```

### For Orchestrator

When dispatching knowledge-manager, include:

```
project: ai-agent-config-template
```

## Rules

1. **Never use a different project name** — all KB operations must use `ai-agent-config-template`
2. **Never create new project folders** — if the folder doesn't exist, create it under the canonical path
3. **Read this file first** when resolving project identity for KB operations

## Update History

- 2026-04-02: Initial creation to address multi-directory issue
