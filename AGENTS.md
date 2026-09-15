# AI Agent Rules

## Cursor 集成说明

本项目以 Cursor 为**首要平台**进行开发流程工具设计。

> **权威定义在 `.cursor/` 下**（Trae 侧镜像在 `.trae/`，两者独立维护）。任何本文件与 `.cursor/rules/spec-workflow.mdc` 不一致之处，**以 `spec-workflow.mdc` 为准**。

| 特性 | 路径 | 说明 |
|------|------|------|
| 核心规则 | `.cursor/rules/spec-workflow.mdc` | Always Apply — 4 Human Gate（HG-1.5 仅 UI）+ 反狡辩准则 |
| 子 Agent | `.cursor/agents/` | 11 个聚焦子Agent（含反狡辩表） |
| 命令 | `.cursor/commands/` | `/feature` + `/bugfix` + `/brief` + `/research` + `/specify` + `/plan` + `/implement` + `/status` + `/wiki` |
| 钩子 | `.cursor/hooks/` | Human Gate 门禁（preToolUse）+ 命令安全守卫（beforeShellExecution）+ 压缩快照（preCompact）+ 会话恢复（sessionStart）+ 漂移提醒（subagentStop）。变更历史见 `.cursor/hooks/CHANGELOG.md` |
| 共享库 | `.cursor/hooks/lib/` | `emit.sh`（输出原语）/ `verdict-parse.sh`（判决解析）/ `status-read.sh`（状态读取） |
| Skill | `.cursor/skills/` | ui-ux-pro-max / code2prompt / drawio-skill / project-build / project-test 等 |
| 片段 | `.cursor/snippets/` | escalation-protocol.md、ui-skill-usage.md |
| MCP | `.cursor/mcp.json` | knowledge-base + playwright |

### 三层约束体系
1. **Rules**（静态，抗压缩）— `spec-workflow.mdc` 永远不会丢失
2. **Hooks**（动态，程序化）— `pipeline-gate.sh` 程序化阻断跳过 Human Gate
3. **Subagents**（独立上下文）— 每个子Agent 有自己的反狡辩表

### 核心设计原则
- Spec 是唯一真相源（所有决策写入 `.specdev/specs/`）
- Human Gate 强制停止确认（需求 → 视觉基准（仅 UI）→ 方案 → Phase 完成）
- 实施类子Agent（implementer/reviewer/verifier）不能自己声明"完成"，必须经过独立验证

### 门禁的失败哲学：fail-closed

> 本项目的门禁**不是**靠"拦住危险操作"体现价值，而是靠**拒绝在信息不足时假装放行**。
> 每一次"读不出来/解析不了/名字不认识"的处置都必须显式决定，且默认是**拒绝**。

已确认过的真实教训（均已成为测试用例）：

| 症状 | 曾经的后果 |
|------|-----------|
| `preToolUse` 返回 `permission:"ask"` | **官方文档明确该值被接受但不执行** → 等同放行。HG-3 的非 PASS 判决因此可被静默放行 |
| 状态文件读失败 → 降级为"全 pending" | 最严重的 fail-open：`current_phase` 为空时 `hg3=passed` **零校验**写入 |
| 写入内容解析为空 → 所有 `grep` 不匹配 | 「读不出去」被当成「没发现问题」 |
| Agent 名字不在白名单 → 走默认分支 | 拼错一个字母即可让全部门禁失效 |
| Hook 输出字段名写错 | 链路**静默失效**（如 sessionStart 的 `additionalContext` vs `additional_context`），测试与日志都显示正常 |
| `code-explorer` 无条件套 `validate_phase_id` | 它的 4 个调用场景中 **3 个发生在 `current_phase` 为空时** → 「设计前调研」这条能力被门禁自己关闭；`/plan` 的文档流程从写下那天起就无法执行 |
| `design.md` 只校验「≥10 行 + 含 `##`」 | 架构决策可以**完全基于推断**通过 HG-2；而 `reviewer-design` 的职责是「对照 design.md **与代码库既有约定**」—— 偏差在最贵的地方才暴露 |

详细勘误与逐条修复记录见 `.cursor/hooks/CHANGELOG.md`；行为测试在 `tools/test-*.sh`（**5 个套件，142 项断言**，全部可重跑）。

### 「设计必须基于现状」的可验收化

「不许猜」是不可验收的主观纪律（与「UI 不得用抽象形容词」同类）。本项目把它变成可判定的形式：

| 机制 | 位置 | 强制方式 |
|---|---|---|
| `code-explorer` 双模式（workflow 级 / phase 级） | `code-explorer.md` | 门禁按 `current_phase` 是否为空分流 |
| `design.md` 必须有「现状依据」章节，每条带 `路径:行号` | `solution-design-output.md` | 门禁在 `hg2=passed` 校验 L1–L5 |
| `Stop & Explore`（需要事实时先查再设计） | `escalation-protocol.md` | agent 契约（**不占用 escalation 通道**） |

> ⚠️ **边界**：门禁保证「**证据指向真实位置**」（路径存在 + 行号不越界），
> **不保证**「**证据支持该断言**」—— 后者是语义判断，属 `reviewer-design`。
> 不要因为门禁是绿的，就以为设计依据一定正确。

## 调度者架构（Cursor 侧现行）

本项目采用 Orchestrator（调度者）驱动的多 Agent 工作流。**调度者是用户唯一直接交互的 Agent**，其职责与边界见 `.cursor/rules/spec-workflow.mdc`。

### 调度者职责

- 通过 Task 工具**一次一个阶段**地派发子 Agent
- 只向下传摘要 + 文件路径；子 Agent 自行读取完整文件
- 子 Agent 只向上回文件路径 + 判决信号；完整文档不回流
- 所有子 Agent 产物落盘到 `.specdev/specs/<slug>/`
- 每个阶段结束后维护 `.specdev/specs/<slug>/current-status.json`
- 上下文压缩后立即读取 `current-status.json` 恢复状态
- reviewer 判决 MUST-FIX → **由调度者**回流 implementer（`loop_count` +1，上限 2 轮，超过即升级给用户；**没有任何 hook 会代你回流**）

### 调度者**不能**做的事

| 禁止 | 原因 |
|------|------|
| 自己写实现代码 | 无 spec 追踪、无分支隔离。必须委托 `implementer` |
| 自己审查代码质量 | 缺少独立上下文，无法客观判断。必须委托 `reviewer-*` |
| 自己运行验证测试 | 必须委托 `verifier`（保持验证独立性） |
| 在用户未确认前推进 Human Gate | Human Gate 的全部价值就是"不被绕过" |
| 让 implementer 在 `main` 上编码 | 每个 Phase 必须在 `impl-<phase-id>` 分支上工作 |

> ⚠️ 「调度者不得自己写实现代码」目前**只有 Rules 层劝阻，没有 hook 程序化拦截**（决策：不启用）。
> `pipeline-gate.sh` 只校验对 `current-status.json` 的写入，其余写入一律放行。
>
> ⚠️ **这条缺口的实际爆炸半径比「写实现代码」更大**：调度者也可以直接写
> `implementation.md` / `review-*.md` / `verification.md`（含 `## 判决：PASS`），
> 而 HG-3 的流程完整性校验是「文件存在 + 判决行可解析」—— **无法区分作者**。
> 即：**文件级的伪造路径可以造出一次看起来完整的审查+验证**。
>
> 部分收紧是可行的（deny 对 `phases/**` 下除 `review.md` 外的写入 —— `review.md` 本就是调度者的合并产物），
> **但前提是先实测 `preToolUse` 能否区分调用者**：若不能区分，该规则会把 reviewer / implementer 自己的产物写入一并拦掉，属不可用。
> 未实测 → 未实施。详见 `.cursor/hooks/CHANGELOG.md` §8.6 P1。

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
3. `.specdev/specs/<slug>/requirements.md`
4. `.specdev/specs/<slug>/ui-spec.md`（UI 工作流）
5. `.specdev/specs/<slug>/design.md`
6. `.specdev/specs/<slug>/visual-baseline.md`（冻结 token，UI 工作流）
7. `.specdev/specs/<slug>/phases/<phase-id>/spec.md`

When two agents disagree on facts (not design decisions):

| 事实类别 | 谁赢 |
|---------|------|
| 仓库现状（文件/依赖/调用链是否存在） | `code-explorer`（workflow 级报告用于设计依据，phase 级报告用于实施范围） |
| 实测结果（测试是否通过、行为是否正确） | `verifier` |
| 需求解释（AC 到底要求什么） | `requirement-analyst` |
| 视觉偏差（是否偏离冻结 token / 布局骨架） | `reviewer-visual`，必要时以截图证据为准 |
| `reviewer-*` 与 `implementer` 僵持 | 升级给调度者裁决；调度者无法裁决则升级给用户 |

**NEVER default to "the agent that ran later wins."**

### Subagent Rules

- Each subagent writes its complete output to the designated file in `.specdev/specs/<slug>/`
- Each subagent returns ONLY the output file path (plus verdict signals for reviewer/verifier) to the Orchestrator
- Each subagent reads upstream output files directly based on its Input definition
- Subagents must not expand scope beyond what upstream documents define


## Knowledge Base MCP

This project integrates with a personal Knowledge Base through MCP. Use knowledge-base tools as the default persistence and retrieval layer for notes, summaries, research, and prior conversations.

MCP is the preferred sync path in this template.

> ⚠️ **KB 同步由调度者直接执行**，不存在专职的知识库 agent。
> 调度者按 `.cursor/rules/spec-workflow.mdc` 的「Knowledge Base 同步」章节直接调用 MCP 完成。
> 同步是**非阻塞**的：发起即继续，失败不阻塞 Pipeline。

### 同步触发点

| 触发点 | 目标路径 | 内容 |
|--------|---------|------|
| HG-1 通过 | `Projects/<slug>/Topics/` | `requirements.md` |
| HG-2 通过 | `Projects/<slug>/Decisions/` | `design.md` |
| HG-3 通过（**不可跳过**） | `Projects/<slug>/Phases/<phase-id>/` | `spec.md` / `repo-exploration.md` / `implementation.md` / `review.md` / `verification.md` |
| 上下文压缩 | `Projects/<slug>/Snapshots/` | 压缩会话摘要 |
| 用户显式要求 | 按用户指示 | 立即同步 |

MCP 不可用时，将待同步内容写入 `.specdev/specs/<slug>/kb-pending/` 供后续重试。


## Browser MCP

This project also exposes a Playwright MCP server (`playwright`) so that subagents can drive a real headless browser for UI validation: navigate pages, click, fill forms, take snapshots / screenshots, observe console messages and network requests.

- **Configured in**: `.cursor/mcp.json`（Cursor 侧生效）；`.mcp.json` 为 Trae / Claude Code / Windsurf 共用的镜像配置
- **Backend**: reuses the system Chrome at `/usr/bin/google-chrome`, headless + isolated + no-sandbox by default
- **使用者**：
  - `verifier` — **`ui: true` 的 Phase 中为强制手段**，不可用则降级 bash + 项目内 Playwright，并判 `PARTIAL` + 标 `visual-blocking: true`
  - `implementer` — 生成静态原型截图取证
- **Entry tools**: `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`, etc. (see Playwright MCP docs)
- **Fallback**: MCP 不可用时退回 bash + 项目内 Playwright（见 `verifier.md` 的 Frontend Validation Strategy）。**兜底失败不是静默放行的理由** —— 必须标记 blocking 交由用户在 HG-3 显式决策。

## UI/UX Skill 与视觉信息链（Cursor 侧）

> 本节描述 **Cursor 侧实际生效的实现**。Trae 侧的对应实现见 `.trae/`（同一套流程、独立载体）。

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

`.specdev/specs/<slug>/tech-debt-registry.md` 是本工作流所有技术债的**唯一定义来源**（每个工作流一份，非全局一份）。
模板：`.specdev/tech-debt-registry-template.md`（`/feature` 初始化时自动复制）。

> ⚠️ 「`A 依赖 B 接口」这类跨模块假设必须先查注册表**再**信任 —— 注册表里的桩不是实现。

### Rules

- **Single source of truth**: No agent should maintain a separate debt list — everything goes through the registry
- **Write on creation**: When creating stub/placeholder code, immediately register it
- **Read before trusting**: Before depending on an existing interface, check if it's in the registry
- **Update on resolution**: When a stub is filled in, move it from "active" to "resolved"
- **Cross-reference on review**: Reviewer compares code against registry to catch unregistered stubs
- **Validate on verification**: Verifier uses registry to skip known stubs and flag suspected new ones

### 程序化强制（gate 层）

`pipeline-gate.sh` 在写入 `hg3=passed` 时会校验注册表：

1. 注册表文件必须存在（不存在 → deny，并提示从模板复制）
2. 本 Phase 实际产出的 `@STUB(...)` 标记必须能在注册表中找到对应条目

**没有登记的桩 = 不允许通过 Phase 验收。** 这条是程序化的，不依赖 agent 自觉。

### 分工

| 角色 | 职责 |
|------|------|
| `implementer` | 创建 `@STUB(phase-N)` 后立即注册；编码完成后自检是否有未注册的桩 |
| `reviewer-*` | 发现未标注的桩/缺陷 → 新增条目；对照注册表，已知桩不误报为「新发现」 |
| `verifier` | 独立验证发现的疑似桩 → 新增条目；已知桩跳过行为验证 |
| 调度者 | Phase Entry Gate 时向用户呈现继承债务；Phase Closure 时同步推迟项 |

**⚠️ 关于 KB 工具：调度者可直接调用 `search_documents` / `list_documents` 用于**定位**相关工作；create/update/sync 按上面的「Knowledge Base MCP」章节执行。**

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

### KB Sync Rules

- `project` 标识取自工作流 slug（`.specdev/specs/<slug>/` 目录名）
- A checkpoint is not complete until sync action has actually executed and returned success or failure
- If sync fails twice, report to user and continue the pipeline — do not block indefinitely
- On compression recovery, check `.specdev/specs/<slug>/current-status.json` for any pending KB checkpoints and execute them before continuing
- If KB sync is unavailable, write pending files to `.specdev/specs/<slug>/kb-pending/` and retry at pipeline end
- `[KB_PENDING]` files contain full sync content with YAML frontmatter for retry

