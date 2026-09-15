# AI Agent Rules

## Cursor 集成说明

本项目以 Cursor 为**首要平台**进行开发流程工具设计。

> ⚠️ **`.opencode/` 目录已退化为历史参考**：其中已无 `skills/`、`snippets/`、`agents/` 子目录。
> 下文凡引用 `.opencode/skills/...`、`.opencode/snippets/...`、`.opencode/agents/...` 的内容均为 OpenCode 时代残留，
> **不要在 Cursor 下按那些路径调用**。Cursor 侧的权威定义在 `.cursor/` 下（见下节「Cursor 侧实际结构」）。

| 特性 | 路径 | 说明 |
|------|------|------|
| 核心规则 | `.cursor/rules/spec-workflow.mdc` | Always Apply — 3 Human Gate + 反狡辩准则 |
| 子 Agent | `.cursor/agents/` | 11 个聚焦子Agent（含反狡辩表） |
| 命令 | `.cursor/commands/` | `/feature` + `/bugfix` + `/brief` + `/research` + `/specify` + `/plan` + `/implement` + `/status` + `/wiki` |
| 钩子 | `.cursor/hooks/` | Human Gate 门禁（preToolUse）+ 自动推进（subagentStop）+ 压缩快照（preCompact） |
| Skill | `.cursor/skills/` | ui-ux-pro-max / code2prompt / drawio-skill / project-build / project-test 等 |
| 片段 | `.cursor/snippets/` | escalation-protocol.md、ui-skill-usage.md |
| MCP | `.cursor/mcp.json` | knowledge-base + playwright |

### 三层约束体系
1. **Rules**（静态，抗压缩）— `spec-workflow.mdc` 永远不会丢失
2. **Hooks**（动态，程序化）— `pipeline-gate.sh` 程序化阻断跳过 Human Gate
3. **Subagents**（独立上下文）— 每个子Agent 有自己的反狡辩表

### 核心设计原则
- Spec 是唯一真相源（所有决策写入 `.specdev/specs/`）
- Human Gate 强制停止确认（需求 → 方案 → Phase 完成）
- 实施类子Agent（implementer/reviewer/verifier）不能自己声明"完成"，必须经过独立验证

## Orchestrator Architecture

<!--
  ⚠️ 本章为 OpenCode 时代的编排规范，**与 Cursor 侧的实际实现存在命名差异**。
  下游若在 Cursor 下工作，请以 `.cursor/rules/spec-workflow.mdc` 为准。

  命名对照（左 = 下文旧称，右 = Cursor 侧实际）：
  | 旧称 | Cursor 侧实际 |
  |------|------|
  | repo-explorer | code-explorer |
  | validator | verifier |
  | reviewer | reviewer-correctness / reviewer-design / reviewer-connectivity / reviewer-visual |
  | requirement-analyst | requirement-analyst（同名） |
  | program-planner / solution-architect | plan-generator |
  | knowledge-manager | 调度者按 `spec-workflow.mdc` 的 KB 同步章节直接执行 |
  | specs/master-spec.md | `.specdev/specs/<slug>/requirements.md` |
  | specs/phases/<id>/ | `.specdev/specs/<slug>/phases/<id>/` |
  | enforcement-gate.mjs | `.cursor/hooks/pipeline-gate.sh` |
  | 2 个 Human Gate | 3 个 Human Gate（+ UI 工作流的 HG-1.5） |
  | max 3 rounds | max 2 rounds |
-->

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
- **Phase Preparation**: Before each new Phase, run repo-explorer (Stage 4.5) to explore the current codebase, writing to `specs/phases/<phase-id>/repo-exploration.md`. Optionally run code-analyst (Stage 4.6) for deep per-phase analysis.
- **Every phase has independent exploration**: Each phase gets its own per-phase exploration at `specs/phases/<phase-id>/repo-exploration.md`. The global `specs/exploration/repo-exploration.md` from Stage 1 serves as background for early planning stages (requirement-analyst, program-planner) before per-phase explorations are generated.
- **Phase Entry Gate**: Before Phase Preparation for Phase 2+, read `specs/tech-debt-registry.md` and present inherited debt to user for confirmation
- **Tech Debt Registry**: All agents read and write `specs/tech-debt-registry.md` as the single source of truth for outstanding technical debt. New stubs are registered; resolved stubs are moved to resolved section.
- **Pipeline iron rule**: Every sub-spec MUST go through the full implementer → reviewer → validator cycle. The orchestrator has NO authority to skip any stage. The ONLY exception is when the user explicitly says "跳过审查" or "跳过验证".
- **Enforcement plugin awareness**: The `enforcement-gate.mjs` plugin programmatically blocks the Orchestrator from editing non-specs files and running unauthorized commands. If the Orchestrator receives a "Permission denied" message, it indicates a pipeline bypass was blocked — the Orchestrator MUST delegate the blocked action to the appropriate subagent immediately.
- **Agent outputs are direct**: Agents no longer return content summaries to the orchestrator. They return only file paths. The orchestrator reads output files directly when it needs to make decisions. Agents read upstream output files directly — no information passes through orchestrator summarization.
- **Interaction Protocol (UPDATED)**: All user input falls into Category A (pipeline commands) or Category B (everything else). There is NO Category C. If reading any file is needed to answer, the Orchestrator MUST dispatch a subagent.

### Escalation Rules

**Reference**: `.cursor/snippets/escalation-protocol.md` for the full taxonomy, output format, and conflict resolution rules.

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

- **Configured in**: `.cursor/mcp.json`（Cursor 侧生效）；`opencode.jsonc -> mcp.playwright` 与 `.mcp.json` 为镜像配置
- **Backend**: reuses the system Chrome at `/usr/bin/google-chrome`, headless + isolated + no-sandbox by default
- **使用者**：
  - `verifier` — **`ui: true` 的 Phase 中为强制手段**，不可用则降级 bash + 项目内 Playwright，并判 `PARTIAL` + 标 `visual-blocking: true`
  - `implementer` — 生成静态原型截图取证
- **Entry tools**: `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`, etc. (see Playwright MCP docs)
- **Fallback**: MCP 不可用时退回 bash + 项目内 Playwright（见 `verifier.md` 的 Frontend Validation Strategy）。**兜底失败不是静默放行的理由** —— 必须标记 blocking 交由用户在 HG-3 显式决策。

## UI/UX Skill 与视觉信息链（Cursor 侧）

> 本节描述 **Cursor 侧实际生效的实现**。`.opencode/` 目录当前仅保留 OpenCode 时代的编排说明作为历史参考，
> 其中引用的 `.opencode/skills/`、`.opencode/snippets/`、`.opencode/agents/` **均不存在**，不要按那些路径调用。

### Skill 位置与调用方

| 项 | 值 |
|------|------|
| Skill 路径 | `.cursor/skills/ui-ux-pro-max/` |
| 调用规范 | `.cursor/snippets/ui-skill-usage.md` |
| 唯一执行者 | `plan-generator`（在设计阶段一次性生成设计系统） |
| 消费方 | `implementer`（按 token 实现）、`reviewer-visual`（对照反模式与 token）、`verifier`（基准对比 ground truth） |

### 调用方式

- **不采用「动态 snippet 注入」**。Cursor 的 skill 由 agent 通过显式 bash 调用，不需要调度者在 dispatch 时拼接 snippet。
- 调用命令（plan-generator 执行）：

```bash
python3 .cursor/skills/ui-ux-pro-max/scripts/search.py \
  "<产品类型> <行业> <风格关键词>" \
  --design-system --persist -p "<项目 slug>"
```

- 落盘位置：`design-system/<slug>/MASTER.md` + `design-system/<slug>/pages/<page>.md`
- `implementer` / `reviewer-visual` / `verifier` **禁止**自行调用该 skill 生成新设计系统 —— 视觉方向已在 HG-1.5 冻结，只能消费。

### 视觉信息链（端到端）

偏差的根因不是「描述不够详细」，而是链路上没有任何环节承载「界面长什么样」。
因此在既有流程中插入了一条完整的信息链，**每一环都有落盘产物与责任人**：

| 环节 | 载体 | 责任人 | 门禁 |
|------|------|------|:--:|
| 需求 | `.specdev/specs/<slug>/ui-spec.md`（布局骨架 / 状态矩阵 / 断点行为） | `requirement-analyst` | HG-1 |
| 设计 | `design-system/<slug>/MASTER.md` + `.specdev/specs/<slug>/visual-baseline.md`（冻结 token） | `plan-generator` | **HG-1.5** |
| 实施 | 静态原型 + 截图 → `implementation.md ## Prototype（待确认）` | `implementer` | **原型确认门禁** |
| 审查 | `phases/<phase>/review-visual.md`（第 4 并行视角） | `reviewer-visual` | 合并判决 |
| 验证 | 基准对比表 + 4 断点矩阵 + 状态矩阵 + `screenshots/<phase>/` | `verifier` | HG-3（`visual-blocking` 不可静默放行） |

### 三条铁律

```
❌ 禁止抽象形容词 —— 不写「美观/现代/简洁/响应式适配」，一律给具体值（色值 / px / 断点行为）
❌ 禁止文字描述布局 —— 必须有 ASCII 布局骨架，纯文字必然歧义
❌ 禁止只写「列表页」 —— 状态必须穷举（default / loading / empty / error / disabled …）
```

### 设计资产归属

- `design-system/<project-slug>/MASTER.md` 是**目标项目**的设计唯一真相源，随目标项目仓库提交（不提交回本模板仓库）。
- 本模板只提供 skill；下游项目自行生成自己的 `design-system/`。

### Rollback

移除本集成：
1. `rm -rf .cursor/skills/ui-ux-pro-max .cursor/snippets/ui-skill-usage.md`
2. 移除本节 + `.cursor/rules/spec-workflow.mdc` 中的 HG-1.5 / 原型门禁章节
3. 移除 `.cursor/agents/reviewer-visual.md`
4. 撤销 `requirement-analyst` / `plan-generator` / `implementer` / `verifier` 中的 UI 章节

## Project Operation Skills (Auto-Evolving)

This template ships with skeleton skills that agents maintain during development:

- `.cursor/skills/project-build/SKILL.md` — Build/compile knowledge, maintained by `implementer`
- `.cursor/skills/project-test/SKILL.md` — Test/validation knowledge, maintained by `verifier`

These skills start as empty skeletons. Agents update them after successful operations, accumulating project-specific knowledge, and load them explicitly when a build/test is needed.

### Rules

- Agents MUST check and load the relevant skill before performing build/test operations
- Agents MUST update the skill after successful operations if new knowledge was gained
- Skills are project-specific — each downstream project generates its own content
- **Correction over accumulation**: If an agent finds a wrong entry in a skill, it MUST correct or deprecate it. Wrong knowledge actively harms downstream agents.
- **Verification state**: Every knowledge entry in a skill should have a verification status (verified / deprecated / unverified) and a last-verified timestamp.
- **Cross-agent verification**: verifier may update project-build skill; implementer may update project-test skill. Skills are not single-agent silos.
- Never delete accumulated knowledge from skills — mark deprecated entries as ⚠️ 已过期 with a reason instead of deleting them

## Tech Debt Registry

`specs/tech-debt-registry.md` is the unified technical debt registry. All phases share one file.

> Cursor 侧实际路径：`.specdev/specs/<slug>/tech-debt-registry.md`（每个工作流一份，非全局一份）。

### Rules

- **Single source of truth**: No agent should maintain a separate debt list — everything goes through the registry
- **Write on creation**: When creating stub/placeholder code, immediately register it
- **Read before trusting**: Before depending on an existing interface, check if it's in the registry
- **Update on resolution**: When a stub is filled in, move it from "active" to "resolved"
- **Cross-reference on review**: Reviewer compares code against registry to catch unregistered stubs
- **Validate on verification**: Validator uses registry to skip known stubs and flag suspected new ones

**⚠️ ENFORCEMENT: These tools are listed for SUBAGENT use (primarily `knowledge-manager`). The Orchestrator MUST NOT use knowledge-base MCP tools directly for sync operations — dispatch `knowledge-manager` instead. The Orchestrator MAY use `search_documents` and `list_documents` ONLY for locating relevant prior work when asked. All create/update/sync operations go through `knowledge-manager`.**

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

<!--
  ⚠️ Cursor 侧差异：**没有 `knowledge-manager` agent，也没有 `.opencode/snippets/kb-sync-sop.md`
     与 `.opencode/project-config.md`**。KB 同步由调度者（Cursor Agent）按
     `.cursor/rules/spec-workflow.mdc` 的「Knowledge Base 同步」章节直接调用 MCP 完成。
     权威说明以 `spec-workflow.mdc` 为准，下文保留 OpenCode 侧原始描述供对照。
-->

KB sync is executed by the `knowledge-manager` subagent. The Orchestrator's only job is to **dispatch it at the right time**. All sync procedures, object models, naming conventions, and merge rules are defined in `knowledge-manager.md` and the KB sync SOP — the Orchestrator does not need to know these details.

### Mandatory Dispatch Points

| When | What to Sync |
|------|-------------|
| After requirement-analyst completes / HG-1 passed | Topic Doc（`requirements.md`） |
| After HG-2 passed | Decision Doc（`design.md`） |
| After verifier completes / HG-3 passed (**NEVER skip**) | Task Doc（`verification.md`，UI 工作流含 `visual-baseline.md`） |
| On context compression | Snapshot Doc + Daily Digest (if pipeline has progressed) |
| On explicit user request (e.g. "同步知识库") | Immediate sync per user instruction |

### Rules

- `project` 标识取自工作流 slug（`.specdev/specs/<slug>/` 目录名）
- A checkpoint is not complete until sync action has actually executed and returned success or failure
- If sync fails twice, report to user and continue the pipeline — do not block indefinitely
- On compression recovery, check `.specdev/specs/<slug>/current-status.json` for any pending KB checkpoints and execute them before continuing
- If KB sync is unavailable, write pending files to `.specdev/specs/<slug>/kb-pending/` and retry at pipeline end
- `[KB_PENDING]` files contain full sync content with YAML frontmatter for retry
