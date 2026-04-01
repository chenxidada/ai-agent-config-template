# AI Agent Rules

## Orchestrator Architecture

This project uses an Orchestrator-driven multi-agent workflow. The Orchestrator is the default primary agent and the only agent the user interacts with directly.

### Orchestrator Rules

- The Orchestrator dispatches subagents via the Task tool, one stage at a time
- The Orchestrator passes only summaries + file paths downward; subagents read full files themselves
- Subagents return only 3-5 sentence summaries + output file paths upward; full documents never flow back
- All subagent outputs go to the `specs/` directory
- The Orchestrator maintains `specs/current-status.md` after every stage completion
- After context compression, the Orchestrator must immediately read `specs/current-status.md` to recover state
- Two fixed Human Gates: before implementation, and after each sub-spec completes
- reviewer must-fix triggers auto-loop to implementer (max 3 rounds)
- validator fail triggers auto-loop to implementer (max 3 rounds)
- Exceed max rounds -> escalate to user

### Subagent Rules

- Each subagent writes its complete output to the designated file in `specs/`
- Each subagent returns only a summary to the Orchestrator, not the full document
- Each subagent reads upstream files from `specs/` as needed based on its Input definition
- Subagents must not expand scope beyond what the Orchestrator dispatched

### Pipeline Commands

- `/feature <desc>` - New feature development
- `/bugfix <desc>` - Bug investigation and fix
- `/idea <desc>` - Idea exploration (no implementation)
- `/rebuild <desc>` - System rebuild
- `/fullflow <desc>` - Full 13-stage workflow
- `/analyze <desc>` - Codebase/module analysis (human-readable report, no code changes)

See `ORCHESTRATOR_ARCHITECTURE.md` for the complete architecture specification.

## Knowledge Base MCP

This project integrates with a personal Knowledge Base through MCP. Use knowledge-base tools as the default persistence and retrieval layer for notes, summaries, research, and prior conversations.

MCP is the only official sync path in this template. Do not rely on parallel local HTTP sync scripts as the primary write mechanism.

## Preferred Tool Categories

### Documents

Use these tools for document-centric workflows:

- `save_document`
- `get_document`
- `list_documents`
- `update_document`
- `delete_document`
- `search_documents`
- `get_recent_documents`
- `toggle_favorite`
- `toggle_pin_document`
- `move_document`
- `duplicate_document`

### Folders and Tags

- `list_folders`
- `create_folder`
- `get_folder`
- `update_folder`
- `list_tags`
- `create_tag`
- `update_tag`
- `get_tag_hierarchy`
- `recommend_tags`

### Conversations and Summaries

- `list_conversations`
- `get_conversation`
- `summarize_conversation`
- runtime event sync
- structured object sync
- sync object status lookup
- folder path resolver

### Graph and Discovery

- `get_document_links`
- `get_document_backlinks`
- `create_link`
- `get_knowledge_graph`
- `get_document_graph`
- `get_hot_documents`

### Templates and Imports

- `list_templates`
- `create_from_template`
- `export_document`
- `import_document`
- `list_assistant_templates`

## Default Workflow

- When the user asks to save notes, findings, plans, or code summaries: use MCP sync tools and prefer structured object sync for structured records
- When the user asks about prior work: start with `search_documents`, `list_documents`, `list_conversations`, or object sync status lookup
- When organizing content: use folders and tags rather than leaving notes unstructured
- When a task produces durable value: prefer saving a structured document over leaving it only in chat history

## Sync Trigger Model

Knowledge sync uses three trigger classes:

1. Automatic compression trigger
   - Fire on conversation compression, context reset, or workflow handoff
   - Must create one new `Snapshot Doc`
   - Must update today's `Daily Digest`
2. Automatic workflow checkpoint trigger
   - Fire when a workflow reaches a major completed checkpoint
   - Typical checkpoints: requirement clarification, architecture decision, implementation milestone, validation completion, major debugging conclusion
   - Must extract the new high-value result and sync the matching `Task`, `Topic`, `Decision`, or `Daily` object
3. Manual user trigger
   - Fire when the user explicitly asks to summarize, refine, or sync something into the knowledge base
   - Must treat the request as an immediate sync task and choose the best matching object type

This template is intentionally not using noisy real-time logging. Sync should happen automatically at compression boundaries and workflow checkpoints, plus manually on explicit user request.

## Unified Knowledge Object Model

- `Task Doc` -> `Projects/<project>/Tasks/` -> `[task:<task-id>] <project> - <task-name>`
- `Topic Doc` -> `Projects/<project>/Topics/` -> `[topic:<topic-key>] <project> - <topic-name>`
- `Decision Doc` -> `Projects/<project>/Decisions/` -> `[decision:<decision-key>] <project> - <decision-name>`
- `Snapshot Doc` -> `Projects/<project>/Snapshots/` -> `[snapshot:YYYYMMDD-HHmmss] <project> - <label>`
- `Daily Digest` -> `Daily/<YYYY>/<YYYY-MM>/` -> `[daily] YYYY-MM-DD - <project>`

Update semantics:

- `Task`, `Topic`, `Decision`, and `Daily` are appendable or updateable objects
- `Snapshot` is create-only for each compression, reset, or handoff event
- Always resolve folders by logical path and name, never by hardcoded IDs
- Always read an existing appendable document before updating it

## Conversation Compression Sync

When context compression or conversation reset happens, sync the summary into the knowledge base before continuing substantive work.

### Required Flow

1. Create one new `Snapshot Doc` in `Projects/<project>/Snapshots/`
2. Use the title format `[snapshot:YYYYMMDD-HHmmss] <project> - <label>`
3. Resolve the daily folder path `Daily/<YYYY>/<YYYY-MM>/`
4. Find today's `Daily Digest` named `[daily] YYYY-MM-DD - <project>`
5. If the daily document exists:
   - read it first
   - merge only new high-value continuity information
   - update it without overwriting unrelated sections
6. If the daily document does not exist:
   - create it with links to the new snapshot, current blockers, and next actions
7. If the compression produces a durable architectural or product conclusion, also create or update a `Decision Doc` or `Topic Doc`

## Important Rules

- Never hardcode folder IDs
- Always resolve folders dynamically by logical path
- Never overwrite an existing task, topic, decision, or daily document without reading and merging first
- Never collapse compression output into one catch-all daily note; create a `Snapshot Doc` and then update the `Daily Digest`
- Keep structured object writes on structured object sync and runtime-triggered writes on runtime event sync
- Do not say a checkpoint is synced unless a sync action was actually executed
- Workflow checkpoint sync is required behavior, not just documentation guidance
- If sync fails, retry once; if it still fails, tell the user clearly
