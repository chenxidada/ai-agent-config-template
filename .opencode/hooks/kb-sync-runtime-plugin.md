# KB Sync Runtime Plugin

## Purpose

This plugin turns the KB sync rules into actual OpenCode runtime behavior.

Configured in:

- `opencode.jsonc`

Implemented in:

- `.opencode/plugins/kb-sync-runtime.mjs`

## What it does

### 1. Compression runtime trigger

Uses OpenCode event hooks to react to `session.compacted`.

Runtime action:

- submit an async follow-up prompt to `knowledge-manager`
- require `Snapshot Doc` creation
- require `Daily Digest` update

### 2. Manual sync trigger

Uses:

- `chat.message`
- `command.execute.before`

If the current request contains phrases such as:

- `总结并同步`
- `同步到知识库`
- `sync to kb`

the plugin injects a synthetic instruction that forces immediate MCP sync behavior.

### 3. Runtime contract injection

Uses `experimental.chat.system.transform` to inject a persistent KB sync contract into the system prompt.

This keeps OpenCode aware that:

- checkpoint sync is mandatory
- compression sync is mandatory
- sync is not complete until real MCP writes run

### 4. Compaction context injection

Uses `experimental.session.compacting` to preserve enough context for the post-compaction KB sync step.

## Limits

Current runtime behavior is strongest for:

- compression-triggered sync
- manual summarize-and-sync requests

Workflow checkpoint sync is implemented through a combination of:

- workflow snippets that explicitly route through `knowledge-manager`
- the runtime contract injected by this plugin

If you want even stricter checkpoint automation later, add a dedicated workflow orchestrator callback that emits stage-completed events into the same shared sync path.
