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

- `/feature <desc>` - New feature development (unified pipeline)
- `/bugfix <desc>` - Bug investigation and fix (unified pipeline)
- `/rebuild <desc>` - System rebuild (unified pipeline)
- `/idea <desc>` - Idea exploration (stops after solution-architect, no implementation)
- `/analyze <desc>` - Codebase/module analysis (human-readable report, no code changes)

`/feature`, `/bugfix`, and `/rebuild` share the same unified pipeline structure. The intent tag determines scope and emphasis, not the pipeline shape. See `ORCHESTRATOR_ARCHITECTURE.md` for the complete architecture specification.

## Knowledge Base MCP

This project integrates with a personal Knowledge Base through MCP. Use knowledge-base tools as the default persistence and retrieval layer for notes, summaries, research, and prior conversations.

MCP is the preferred sync path in this template. When MCP is unavailable in subagent context, knowledge-manager falls back to writing pending sync files to `specs/kb-pending/` for later retry.

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

## Knowledge Base Sync

KB sync is executed by the `knowledge-manager` subagent. The Orchestrator's only job is to **dispatch it at the right time**. All sync procedures, object models, naming conventions, and merge rules are defined in `knowledge-manager.md` and `.opencode/snippets/kb-sync-sop.md` — the Orchestrator does not need to know these details.

### Mandatory Dispatch Points

| When | What to Sync |
|------|-------------|
| After requirement-analyst completes | Topic Doc or Decision Doc |
| After Human Gate 1 (user confirms design) | Decision Doc for architecture |
| After validator completes (**NEVER skip**) | Task Doc with implementation result |
| On context compression | Snapshot Doc + Daily Digest (if pipeline has progressed) |
| On explicit user request (e.g. "同步知识库") | Immediate sync per user instruction |

### Rules

- Always pass `project` identifier from `.opencode/project-config.md` when dispatching knowledge-manager
- A checkpoint is not complete until sync action has actually executed and returned success or failure
- If sync fails twice, report to user and continue the pipeline — do not block indefinitely
- On compression recovery, check `specs/current-status.md` for any pending KM checkpoints and execute them before continuing
- If knowledge-manager reports `[KB_PENDING]`, the Orchestrator should retry MCP sync at pipeline end or on the next manual `/sync` command
- `[KB_PENDING]` files are stored in `specs/kb-pending/` and contain full sync content with YAML frontmatter for retry
