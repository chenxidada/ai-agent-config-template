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
- **Phase Preparation**: Before each new Phase (Phase 2+), run repo-explorer (Stage 4.5) to re-explore the now-modified codebase, writing to `specs/phases/<phase-id>/repo-exploration.md`. Optionally run code-analyst (Stage 4.6) for deep per-phase analysis.
- **First phase uses global exploration**: Phase 1 uses `specs/exploration/repo-exploration.md` from initial exploration. Subsequent phases each get their own per-phase exploration at `specs/phases/<phase-id>/repo-exploration.md`.
- **Phase Entry Gate**: Before Phase Preparation for Phase 2+, read `specs/tech-debt-registry.md` and present inherited debt to user for confirmation
- **Tech Debt Registry**: All agents read and write `specs/tech-debt-registry.md` as the single source of truth for outstanding technical debt. New stubs are registered; resolved stubs are moved to resolved section.
- **Pipeline iron rule**: Every sub-spec MUST go through the full implementer → reviewer → validator cycle. The orchestrator has NO authority to skip any stage. The ONLY exception is when the user explicitly says "跳过审查" or "跳过验证".
- **Agent outputs are direct**: Agents no longer return content summaries to the orchestrator. They return only file paths. The orchestrator reads output files directly when it needs to make decisions. Agents read upstream output files directly — no information passes through orchestrator summarization.

### Escalation Rules

**Reference**: `.opencode/snippets/escalation-protocol.md` for the full taxonomy, output format, and conflict resolution rules.

- **When in doubt, STOP. Do NOT guess.** An agent that guesses is worse than an agent that escalates.
- Every agent has role-specific Stop & Escalate Conditions in its definition. These are not optional — they are part of the agent's contract.
- An agent escalates by returning output in the escalation format (`## ⚠️ ESCALATION — <Level>`) INSTEAD OF its normal output.
- The Orchestrator MUST check every agent return for escalation before proceeding to the next stage.

#### ⚫ CRITICAL — Stop the World

If ANY agent discovers a finding that meets ALL of these criteria:
1. Affects the correctness, security, or data integrity of COMPLETED phases
2. Cannot be contained within the current phase/sub-spec
3. Would cause incorrect behavior if the pipeline continues without addressing it

→ The agent MUST escalate as ⚫ CRITICAL. The Orchestrator MUST halt ALL active pipelines. No new agents may be dispatched. The user decides whether to continue, re-scope, or abort.

Examples of ⚫ CRITICAL triggers:
- Security vulnerability in a frozen interface (Phase 1 interface has a buffer overflow)
- Data corruption pattern that silently produces wrong results across phases
- Fundamental architectural violation (e.g., no-exceptions codebase discovers exception-throwing path in frozen layer)
- Build system regression that prevents ALL phases from compiling

#### Conflict Resolution Precedence

When two authoritative sources disagree, resolve by this hierarchy (highest wins):
1. Original design document (user-provided)
2. User verbal/written confirmation during pipeline
3. `specs/requirements/requirements.md`
4. `specs/master-spec.md`
5. `specs/phases/<phase-id>/requirements.md`
6. `specs/phases/<phase-id>/phase-spec.md`
7. `specs/phases/<phase-id>/slices/<id>/sub-spec.md`

When two agents disagree on facts (not design decisions):
1. `repo-explorer` wins on repository reality
2. `validator` wins on empirical test results
3. `requirement-analyst` wins on requirements interpretation
4. `reviewer` and `implementer` disagreement → escalate to Orchestrator for deadlock resolution

**NEVER default to "the agent that ran later wins."**

### Subagent Rules

- Each subagent writes its complete output to the designated file in `specs/`
- Each subagent also writes a Chinese translation to `<path>-zh.md`
- Each subagent returns ONLY the output file path (plus verdict signals for reviewer/validator) to the Orchestrator
- Each subagent reads upstream output files directly from `specs/` based on its Input definition
- Subagents must not expand scope beyond what upstream documents define

### Pipeline Commands

- `/feature <desc>` - New feature development (unified pipeline)
- `/bugfix <desc>` - Bug investigation and fix (unified pipeline)
- `/rebuild <desc>` - System rebuild (unified pipeline)
- `/idea <desc>` - Idea exploration (stops after solution-architect, no implementation)
- `/analyze <desc>` - Codebase/module analysis (human-readable report, no code changes)

`/feature`, `/bugfix`, and `/rebuild` share the same unified pipeline structure. The intent tag determines scope and emphasis, not the pipeline shape. See `ORCHESTRATOR_ARCHITECTURE.md` for the complete architecture specification.

### Delegation Matrix

| Responsibility | Agents | Notes |
|---------------|--------|-------|
| Maintain tech-debt-registry | `implementer`, `reviewer`, `validator`, Orchestrator | Update registry when creating/detecting/resolving stubs |

## Knowledge Base MCP

This project integrates with a personal Knowledge Base through MCP. Use knowledge-base tools as the default persistence and retrieval layer for notes, summaries, research, and prior conversations.

MCP is the preferred sync path in this template. When MCP is unavailable in subagent context, knowledge-manager falls back to writing pending sync files to `specs/kb-pending/` for later retry.

## Browser MCP

This project also exposes a Playwright MCP server (`playwright`) so that subagents can drive a real headless browser for UI validation: navigate pages, click, fill forms, take snapshots / screenshots, observe console messages and network requests.

- **Configured in**: `opencode.jsonc -> mcp.playwright` (and mirrored in `.mcp.json`)
- **Backend**: reuses the system Chrome at `/usr/bin/google-chrome`, headless + isolated + no-sandbox by default
- **Granted to**: `validator`, `implementer`, `reviewer` (declared explicitly in each agent frontmatter via `tools.playwright: allow`)
- **Entry tools**: `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`, etc. (see Playwright MCP docs)
- **Fallback**: if the MCP server is unavailable, agents fall back to bash + project-local Playwright as documented in `validator.md`.

## UI/UX Skill 注入规则

This template ships with `ui-ux-pro-max` skill at `.opencode/skills/ui-ux-pro-max/`. Coordination uses **dynamic snippet injection** to avoid polluting non-UI task contexts.

### Orchestrator behavior

When dispatching `solution-architect`, `implementer`, `reviewer`, or `validator`:

1. **Detect UI relevance** in the sub-spec / task description using these keywords:
   - **UI keywords (zh)**: 界面 / 组件 / 样式 / 按钮 / 表单 / 布局 / 响应式 / 暗色模式 / 配色 / 字体 / 动效 / 视觉 / 前端 / 页面
   - **UI keywords (en)**: component / page / UI / layout / responsive / dark mode / button / form / modal / dashboard / landing / banner / icon / shadcn / Tailwind / CSS / animation / accessibility (visual)
   - **Negative keywords (skip injection)**: API only / database / migration / DevOps / CI / cron / schema / pure backend logic
2. **If UI-relevant**: append the contents of `.opencode/snippets/ui-skill-usage.md` to the dispatch prompt under a clearly-marked section `## UI Skill Coordination (auto-injected)`.
3. **If ambiguous (mixed task)**: default to inject (cost is small, missing context is more expensive).
4. **If not UI-relevant**: do NOT inject. Zero token overhead.

### Subagent behavior

- Subagents call the skill via **explicit bash** (`python3 .opencode/skills/ui-ux-pro-max/scripts/search.py ...`), NOT via skill auto-routing.
- The orchestrator never invokes the skill itself; only subagents do.
- The orchestrator must NOT load `ui-ux-pro-max` SKILL.md into its own context.

### Design assets ownership

- `design-system/<project-slug>/MASTER.md` is the project's design single-source-of-truth.
- It is generated by `solution-architect` and committed to the project repo (NOT to this template repo).
- This template ships only the skill; downstream projects generate their own design-system/.

### Rollback

To remove this integration:
1. `rm -rf .opencode/skills/ui-ux-pro-max .opencode/snippets/ui-skill-usage.md`
2. Remove this section from `AGENTS.md`
3. No agent definitions need to change (this is the design's main strength).

## Project Operation Skills (Auto-Evolving)

This template ships with skeleton skills that agents maintain during development:

- `.opencode/skills/project-build/SKILL.md` — Build/compile knowledge, maintained by `implementer`
- `.opencode/skills/project-test/SKILL.md` — Test/validation knowledge, maintained by `validator`

These skills start as empty skeletons. Agents update them after successful operations, accumulating project-specific knowledge. The opencode skill discovery mechanism auto-loads them when relevant (e.g., when an agent needs to compile or test).

### Rules

- Agents MUST check and load the relevant skill before performing build/test operations
- Agents MUST update the skill after successful operations if new knowledge was gained
- Skills are project-specific — each downstream project generates its own content
- **Correction over accumulation**: If an agent finds a wrong entry in a skill, it MUST correct or deprecate it. Wrong knowledge actively harms downstream agents.
- **Verification state**: Every knowledge entry in a skill should have a verification status (verified / deprecated / unverified) and a last-verified timestamp.
- **Cross-agent verification**: validator may update project-build skill; implementer may update project-test skill. Skills are not single-agent silos.
- Never delete accumulated knowledge from skills — mark deprecated entries as ⚠️ 已过期 with a reason instead of deleting them

## Tech Debt Registry

`specs/tech-debt-registry.md` is the unified technical debt registry. All phases share one file.

### Rules

- **Single source of truth**: No agent should maintain a separate debt list — everything goes through the registry
- **Write on creation**: When creating stub/placeholder code, immediately register it
- **Read before trusting**: Before depending on an existing interface, check if it's in the registry
- **Update on resolution**: When a stub is filled in, move it from "active" to "resolved"
- **Cross-reference on review**: Reviewer compares code against registry to catch unregistered stubs
- **Validate on verification**: Validator uses registry to skip known stubs and flag suspected new ones

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
