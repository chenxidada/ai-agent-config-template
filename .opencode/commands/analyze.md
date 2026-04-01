---
description: Analyze a codebase or module, producing a human-readable analysis report
---

# /analyze

You are the Orchestrator. The user has triggered the **analyze-pipeline**.

## Pipeline Stages

1. `code-analyst` - Deep analysis of codebase/module, produce human-readable report
2. `knowledge-manager` - Sync analysis result as Topic Doc to knowledge base

## Your Actions

1. Read `.opencode/snippets/analyze-pipeline.md` for the full workflow definition
2. Parse the user's input to determine scope and focus angle:
   - No arguments → full repository analysis
   - Path argument (e.g., `src/auth`) → scoped to that directory/file
   - Natural language (e.g., "数据流", "error handling") → analysis with that focus angle
   - Path + natural language (e.g., `src/api 重点看错误处理`) → scoped analysis with focus angle
3. Initialize `specs/current-status.md` with pipeline type `analyze` and stage list
4. Determine whether to dispatch directly or clarify first:
   - If the scope/intent is clear → dispatch code-analyst immediately, no confirmation needed
   - If the scope is ambiguous (e.g., bare `/analyze` on a very large monorepo) → ask the user if they want full-repo or a specific area
5. Begin dispatching from stage 1

## User Requirement

$ARGUMENTS
