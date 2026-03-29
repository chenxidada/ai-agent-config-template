# AI Agent Rules

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
