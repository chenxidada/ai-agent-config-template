# Runtime Sync Plan

## Purpose

This document explains how the KB sync trigger model becomes real runtime behavior instead of staying as documentation only.

## What "runtime layer" means

In this template, the runtime layer is the execution mechanism that actually fires sync actions when a trigger happens.

Examples:

- a conversation compression hook
- a reset or handoff hook
- a workflow orchestrator that knows when a stage is completed
- a command router that handles explicit user requests like "summarize and sync"

Without a runtime layer, you only have rules.

With a runtime layer, the system actually calls MCP tools and writes to the knowledge base.

## Required trigger classes

### 1. Compression runtime trigger

Trigger events:

- conversation compression
- context reset
- workflow handoff

Runtime action:

1. summarize the current state
2. create a new `Snapshot Doc`
3. read or create today's `Daily Digest`
4. update the daily note with blockers, links, and next actions

## 2. Workflow checkpoint runtime trigger

Trigger events:

- requirement stage completed
- architecture or design stage completed
- implementation milestone completed
- validation completed
- major debugging conclusion completed

Runtime action:

1. detect the completed stage
2. extract only the stage's new high-value result
3. choose the matching knowledge object
4. run `save_document` or `update_document`

## 3. Manual command runtime trigger

Trigger events:

- user explicitly asks to summarize and sync
- user explicitly asks to refine and save into KB

Runtime action:

1. treat the request as immediate sync work
2. refine the content
3. choose the matching object type
4. execute the MCP write

## Recommended implementation shape

### Option A: Hook-based

Use hooks for:

- compression
- reset
- handoff

This is best for guaranteed session-boundary sync.

### Option B: Workflow orchestrator-based

Use the workflow controller to fire checkpoint sync after major stages.

This is best for:

- requirement workflows
- feature pipelines
- bugfix pipelines
- long staged tasks

### Option C: Command-router based

Use explicit commands to trigger manual sync.

This is best for:

- ad hoc summarization
- selective knowledge extraction
- user-directed persistence

## Minimum viable runtime architecture

To make the trigger model real, the minimum runtime stack should include:

1. one compression hook
2. one workflow checkpoint notifier or orchestrator callback
3. one manual summarize-and-sync command path
4. one shared MCP sync function that follows `snippets/kb-sync-sop.md`

## Shared runtime contract

Every runtime trigger should pass a normalized payload into the shared sync function.

Recommended fields:

- `triggerType`: `compression | checkpoint | manual`
- `project`
- `stage`: `requirement | architecture | implementation | validation | debugging | handoff`
- `objectHint`
- `summary`
- `relatedTaskId`
- `timestamp`

## Success criteria

A trigger is considered successful only if:

- the runtime layer fired
- MCP write actions executed
- the intended KB object was created or updated

It is not enough to:

- mark a stage as synced in logs only
- generate a summary without saving it
- postpone sync until some later undefined step

## Practical interpretation

If you ask, "Do we have the trigger mechanism?", the answer should be judged in two layers:

- specification layer: are the rules defined?
- runtime layer: is there an execution path that actually fires the sync?

The goal of this template is to make both layers consistent.
