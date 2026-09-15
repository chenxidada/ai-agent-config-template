# AI Agent Config Template

一套只保留 `Knowledge Base MCP` 的 AI Agent 配置模板，作为你的通用模板源目录，支持：

- `OpenCode`
- `Cursor`
- `Claude Code`
- `Windsurf`

模板目标：让不同 AI 工具统一接入同一套个人知识库，并把总结、研究、代码笔记、对话沉淀到 `Knownbase / AI-Chat`。

## 文件清单

```text
ai-agent-config-template/
├── opencode.jsonc                  # OpenCode MCP + plugin 配置（镜像）
├── .mcp.json                       # Claude Code / Windsurf MCP 配置（镜像）
├── AGENTS.md                       # 通用规则（含 Cursor 侧差异说明）
├── .cursorrules                    # Cursor 规则（精简版，指向 .cursor/rules/）
├── .windsurfrules                  # Windsurf 规则（精简版）
├── knowledge-base-mcp.sh           # MCP 启动脚本，避免写死路径
├── setup.sh                        # 一键导入脚本
├── .cursor/                        # ★ Cursor 侧权威配置（首选平台）
│   ├── rules/                      # spec-workflow.mdc（Always Apply）
│   ├── agents/                     # 11 个子Agent（含 reviewer-visual）
│   ├── commands/                   # /feature /bugfix /brief /research /specify /plan /implement /status
│   ├── hooks/                      # pipeline-gate.sh 门禁 + pipeline-advance.sh 推进 + pipeline-compact.sh
│   │   └── lib/                    # status-read.sh / verdict-parse.sh（共享库）
│   ├── skills/                     # ui-ux-pro-max / code2prompt / drawio-skill / project-build / project-test 等
│   ├── snippets/                   # escalation-protocol.md / ui-skill-usage.md
│   ├── templates/                  # 需求/设计/UI 规格/视觉基准输出模板
│   └── mcp.json                    # knowledge-base + playwright MCP
├── .specdev/                       # 工作流运行时目录（specs/ 在导入后生成）
│   ├── ui-spec-template.md         # /feature 初始化时复制
│   ├── constitution-template.md
│   └── tech-debt-registry-template.md
├── .opencode/                      # ⚠️ OpenCode 历史参考（已无 skills/snippets/agents 子目录）
└── README.md
```

## 设计说明

这套模板只做一件事：

- 给 AI 工具接入 `knowledge-base` MCP
- 统一知识库工作流
- 在上下文压缩、研究结束、任务收尾时，把结果沉淀到知识库

不再保留和知识库无关的远程构建、刷写、部署技能。

## Cursor 工作流（首选平台）

Cursor 侧不是「知识库同步工具」，而是一套 **Spec 规格文件驱动的开发流程**。所有设计决策、验收标准、审查与验证结果都落到 `.specdev/specs/<slug>/`。

### 核心机制

| 机制 | 实现 | 作用 |
|------|------|------|
| Spec 唯一真相源 | `.specdev/specs/<slug>/` | 需求/设计/每 Phase 的实现与验证全落盘 |
| Human Gate | `pipeline-gate.sh` 程序化阻断 | 用户未明确确认前，物理上无法进入下一阶段 |
| 反狡辩体系 | 每个子Agent 的专属反狡辩表 | 防止 AI 用「编译通过」「写了 N 个测试」跳过关键步骤 |
| 三层约束 | Rules（静态）+ Hooks（动态）+ Subagents（独立上下文） | 抗上下文压缩 |

### 流程（6 阶段 + 4 个确认点）

```text
/feature <描述>
  → requirement-analyst        → requirements.md (+ ui-spec.md 若有界面)
  → 🛑 HG-1  需求确认
  → plan-generator             → design.md + phase-plan.md + (design-system/ + visual-baseline.md)
  → 🛑 HG-1.5 视觉基准确认（仅 UI 工作流）
  → 🛑 HG-2  方案确认
  → [每个 Phase] code-explorer → git 分支 → implementer
                   → 🛑 原型确认（仅 UI Phase：先出静态原型并停止）
                   → implementer 接入真实逻辑
                   → 4 个并行 reviewer（correctness / design / connectivity / visual）
                   → verifier（UI Phase 强制 4 断点 + 状态矩阵截图）
                   → 🛑 HG-3 Phase 验收 → commit + merge 回 main
```

### 前端视觉信息链（UI 工作流专属）

界面偏差的根因不是「描述不够详细」，而是链路上没有环节承载「界面长什么样」。为此插入了一条端到端信息链，**每一环都有落盘产物**：

| 环节 | 产物 | 责任人 | 确认点 |
|------|------|------|:--:|
| 需求 | `.specdev/specs/<slug>/ui-spec.md`（ASCII 布局骨架 / 状态矩阵 / 断点行为） | `requirement-analyst` | HG-1 |
| 设计 | `design-system/<slug>/MASTER.md` + `visual-baseline.md`（冻结 design token） | `plan-generator` | **HG-1.5** |
| 实施 | 静态原型 + 截图（`implementation.md ## Prototype（待确认）`） | `implementer` | **原型确认门禁** |
| 审查 | `review-visual.md`（第 4 并行视角：硬编码 token / 状态缺失 / 反模式） | `reviewer-visual` | 合并判决 |
| 验证 | 基准对比表 + 4 断点矩阵 + 状态矩阵 + `screenshots/<phase>/` | `verifier` | HG-3 |

三条铁律：

```text
❌ 禁止抽象形容词 —— 不写「美观/现代/简洁/响应式适配」，一律给具体值（色值 / px / 断点行为）
❌ 禁止文字描述布局 —— 必须有 ASCII 布局骨架，纯文字必然歧义
❌ 禁止只写「列表页」 —— 状态必须穷举（default / loading / empty / error / disabled …）
```

设计系统由 `.cursor/skills/ui-ux-pro-max/` 生成，调用规范见 `.cursor/snippets/ui-skill-usage.md`。

### 命令一览

| 命令 | 用途 | Phase 拆分 | 审查 |
|------|------|:--:|:--:|
| `/feature <desc>` | 完整新功能开发 | 2-5 Phase + DAG | 四视角并行 |
| `/bugfix <desc>` | Bug 修复 | 单 Phase | 单视角 |
| `/brief <desc>` | 轻量快速开发（< 3 文件） | 单 Phase | 单视角（覆盖四视角） |
| `/research <desc>` | 深度代码调研 | 不实施 | — |
| `/specify <desc>` | 仅需求分析 | 不实施 | — |
| `/plan` | 仅架构设计 | 输出 DAG | — |
| `/implement` | 执行实施（HG-2 已过） | 单 Phase | 四视角并行 |
| `/status` | 查看进度 + 债务快照 | — | — |
| `/wiki` | 项目 Wiki 文档维护 | — | — |

## 建议的 `.opencode/` 目录规范

> ⚠️ **以下为 OpenCode 时代约定，当前 `.opencode/` 已不再包含这些子目录**，仅在需要恢复 OpenCode 侧支持时作为参考。

为了方便你后续继续扩展，当前建议这样组织 `.opencode/`：

- `skills/`：可复用的 OpenCode 技能
- `agents/`：阶段化 agent 预设或角色说明
- `templates/`：提示模板、输出模板、报告模板
- `hooks/`：自动化 helper、hook 说明、脚本
- `snippets/`：短小可复用的任务片段

建议原则：

- 保持项目无关、可复用
- 不在这些模板文件里写死本机路径
- 需要环境差异时，通过环境变量或启动脚本解决
- 任何新增内容都优先回写模板源目录，再通过 `setup.sh` 分发

当前推荐的阶段化 agents：

- `repo-explorer` — 仓库探查
- `requirement-analyst` — 需求分析（支持 create/append 模式）
- `program-planner` — 总体规划（支持 create/update 模式）
- `task-planner` — 阶段任务拆解
- `solution-architect` — 方案设计
- `code-analyst` — 代码分析
- `implementer` — 实现（必须写测试）
- `reviewer` — 代码审查（逻辑 + 测试覆盖度）
- `validator` — 验证（支持前端截图验证）
- `knowledge-manager` — 知识库同步

> ⚠️ 上述为 OpenCode 侧命名。**Cursor 侧实际使用 `.cursor/agents/` 下的 11 个 agent**（命名对照见 `AGENTS.md`
> 的「命名对照」表）：

| Agent | 职责 |
|-------|------|
| `requirement-analyst` | 需求分析（EARS 格式 AC）+ UI 相关性判定 → `requirements.md` / `ui-spec.md` |
| `plan-generator` | 架构设计 + Phase DAG + design system + 视觉基准 |
| `code-explorer` | 每 Phase 前的代码调研（含 UI 组件/主题盘点）→ `repo-exploration.md` |
| `implementer` | 按 spec 实现（UI Phase 走原型先行协议） |
| `reviewer-correctness` | 并行审查：实现正确性 + 桩检测 |
| `reviewer-design` | 并行审查：设计一致性 |
| `reviewer-connectivity` | 并行审查：集成连通性 |
| `reviewer-visual` | 并行审查：视觉一致性（token / 状态 / 断点 / a11y / 反模式） |
| `reviewer` | 单视角审查（覆盖四视角，供 `/brief` 使用） |
| `verifier` | 独立端到端验证（UI Phase 强制视觉证据） |
| `wiki` | 项目 Wiki 文档维护 |

其中知识库同步在 Cursor 侧由调度者按 `.cursor/rules/spec-workflow.mdc` 的「Knowledge Base 同步」章节直接调用 MCP 完成（无 `knowledge-manager` agent）。

推荐的总控 workflow：

- `unified-pipeline`

`/feature`、`/bugfix`、`/rebuild` 共用同一条统一 pipeline，以 intent 标签区分范围和侧重点。Pipeline 以 master-spec 为中心文档，按 phase 为颗粒度循环执行：需求分析 → 总体规划 → 阶段拆解 → 方案设计 → 实现 → 审查 → 验证 → 知识同步。

## 当前 Knowledge Base 能力

当前 `Knownbase / AI-Chat` 已支持较完整的 MCP 能力，常用范围包括：

- 文档：创建、读取、更新、删除、全文搜索、收藏、置顶、移动、复制、回收站
- 文件夹：树结构、创建、更新、删除、置顶
- 标签：创建、更新、删除、层级、推荐、标签分析
- 对话：列出、读取、总结、创建、删除、导出、置顶、收藏
- 知识图谱：正反向链接、图谱总览、热门文档、文档图谱
- 模板：模板创建、模板生成文档、助手模板管理
- 同步：路径解析工具、结构化对象同步、运行时事件同步、对象状态查询
- PDF：单文件/批量上传
- 资源：`kb://folders`、`kb://tags`、`kb://documents/recent`、`kb://graph/overview`
- Prompt：以 `sync-daily-digest`、`sync-snapshot-from-conversation`、`sync-task-status`、`sync-decision-note`、`sync-topic-note`、`runtime-sync-review` 为核心

## 环境要求

| 依赖 | 最低版本 | 用途 |
| ---- | -------- | ---- |
| Node.js | >= 20 | MCP Server 运行时 |
| bash | 常见 Linux 发行版自带 | 启动脚本 |
| Knownbase API | `http://localhost:4000/api/v1` | MCP 依赖的后端 API |

## 模板原则

这是通用模板，不应把某一台机器的绝对路径硬编码进配置文件。

模板中的路径解析原则是：

- 优先使用环境变量 `KNOWNBASE_ROOT`
- 若未设置，则尝试若干常见候选路径
- 无法定位时，给出明确提示，由使用者补充环境变量

本模板通过 `knowledge-base-mcp.sh` 统一启动 MCP，避免在 `opencode.jsonc` 或 `.mcp.json` 中写死具体仓库路径。

推荐设置：

```bash
export KNOWNBASE_ROOT=/path/to/knownbase/AI-Chat
export KB_API_URL=http://localhost:4000/api/v1
```

其中：

- `KNOWNBASE_ROOT` 指向 `AI-Chat` 项目根目录
- `KB_API_URL` 默认为 `http://localhost:4000/api/v1`

如果你不显式设置 `KNOWNBASE_ROOT`，脚本会尝试这些候选路径：

- `$HOME/workspace/code/knownbase/AI-Chat`
- `$HOME/code/knownbase/AI-Chat`
- `$PWD/../knownbase/AI-Chat`
- `$PWD/knownbase/AI-Chat`

## 使用方法

### 方法一：一键导入

```bash
cd /your/project
bash /path/to/ai-agent-config-template/setup.sh
```

脚本会：

1. 复制配置文件（`.mcp.json` / `AGENTS.md` / `.cursorrules` / `knowledge-base-mcp.sh`）
2. 同步模板中的整个 `.cursor/` 目录（规则 + 子Agent + 命令 + 钩子 + skills + snippets + mcp.json）
3. 同步 `.specdev/` 模板（UI 规格 / 宪法 / 技术债注册表）
4. 复制 `knowledge-base-mcp.sh`
5. 将 `opencode.jsonc` 加入 `.gitignore`

> 也可只装 Cursor：`bash setup.sh --cursor`

### 方法二：手动复制

```bash
cd /your/project
cp /path/to/ai-agent-config-template/.mcp.json .
cp /path/to/ai-agent-config-template/AGENTS.md .
cp /path/to/ai-agent-config-template/.cursorrules .
cp /path/to/ai-agent-config-template/knowledge-base-mcp.sh .
cp -R /path/to/ai-agent-config-template/.cursor .
cp -R /path/to/ai-agent-config-template/.specdev .
chmod +x knowledge-base-mcp.sh
```

## 使用建议

知识库相关的典型用法：

- 把研究结果、决策和任务状态保存为结构化文档
- 按对象类型而不是按临时聊天记录组织知识
- 搜索历史结论、方案、代码笔记和任务执行过程
- 读取并总结历史对话，再沉淀成长期可复用记录
- 在上下文压缩时创建 Snapshot Doc，并更新当天的 Daily Digest

推荐优先使用这些工具：

- `list_folders`
- `list_documents`
- `get_document`
- 路径解析工具
- 结构化对象同步
- 运行时事件同步
- 对象状态查询
- `search_documents`

## 重要约定

- 模板统一以 `knowledge-base` MCP 作为唯一官方同步入口
- 不再保留旧的 daily-ingest 风格同步方案
- 不再写死任何 `folderId`
- 一律按逻辑路径逐级解析目标目录，而不是只按一个文件夹名盲查
- 对可更新对象必须先读取已有文档，再做增量合并，不直接覆盖

## 统一触发机制

这套模板要求知识同步真正被触发，而不是只在文档里声明“应该同步”。

统一采用三类触发：

### 1. 自动压缩触发

在这些事件发生时，必须自动执行同步：

- conversation compression
- context reset
- workflow handoff

标准动作：

- 创建一个新的 `Snapshot Doc`
- 更新当天的 `Daily Digest`
- 如本次压缩产出长期结论，再补 `Decision Doc` 或 `Topic Doc`

### 2. 自动阶段触发

在工作流到达关键阶段时，必须自动执行一次 checkpoint sync。

默认阶段点：

- 需求澄清完成
- 架构或方案决策完成
- 一个实现里程碑完成
- 验证完成
- 重要排障结论形成

标准动作：

- 提炼当前阶段新增的高价值信息
- 按对象类型更新 `Task Doc`、`Topic Doc`、`Decision Doc` 或 `Daily Digest`
- 不做实时日志式同步，只做阶段性增量同步
- 默认通过 workflow 中的 `knowledge-manager` 阶段和全局 runtime contract 一起保证触发

### 3. 手动请求触发

当用户明确提出这些意图时，应立即触发同步：

- “总结并同步到知识库”
- “提炼一下并写入知识库”
- “把这次讨论沉淀到 KB”

标准动作：

- 先提炼内容
- 再立即执行 MCP 同步
- 选择最合适的知识对象，而不是一律写成 daily
- OpenCode runtime plugin 会对显式“总结并同步”类请求追加同步指令

## 知识同步策略

模板统一使用对象化知识模型，而不是把所有信息压进一份项目总记录或单一 daily 文档。

### 统一目录规范

```text
Projects/<project>/
  Tasks/
  Topics/
  Decisions/
  Snapshots/

Daily/<YYYY>/<YYYY-MM>/
```

### 统一对象与命名规范

- `Task Doc`
  - 用途：记录某个具体工作流任务的阶段、结果、失败、验证
  - 路径：`Projects/<project>/Tasks/`
  - 命名：`[task:<task-id>] <project> - <task-name>`
- `Topic Doc`
  - 用途：记录某个长期主题的知识积累
  - 路径：`Projects/<project>/Topics/`
  - 命名：`[topic:<topic-key>] <project> - <topic-name>`
- `Decision Doc`
  - 用途：记录重要决策、权衡、影响
  - 路径：`Projects/<project>/Decisions/`
  - 命名：`[decision:<decision-key>] <project> - <decision-name>`
- `Snapshot Doc`
  - 用途：记录压缩、reset、handoff 这类时间点快照
  - 路径：`Projects/<project>/Snapshots/`
  - 命名：`[snapshot:YYYYMMDD-HHmmss] <project> - <label>`
- `Daily Digest`
  - 用途：记录当天执行连续性、导航信息、阻塞项
  - 路径：`Daily/<YYYY>/<YYYY-MM>/`
  - 命名：`[daily] YYYY-MM-DD - <project>`

### 统一触发规则

- 需求确认后：创建或更新 `Topic Doc`，必要时补 `Decision Doc`
- 架构决策后：创建或更新 `Decision Doc`，必要时补 `Topic Doc`
- 实现里程碑后：更新 `Task Doc`，必要时补 `Daily Digest`
- 验证完成后：更新 `Task Doc`
- 重要排障结论后：更新 `Task Doc` 或 `Topic Doc`
- 压缩 / reset / handoff 前：新建 `Snapshot Doc`，并更新 `Daily Digest`

这里的“触发规则”指的是实际要执行同步，不是仅作为建议保留在流程说明里。

### 压缩同步规则

- 压缩事件默认写入 Snapshot Doc
- 当天恢复导航默认写入 Daily Digest
- 不再把压缩摘要直接等同于单一 daily 文档正文
- 如本次压缩产出重大长期结论，再额外补 `Decision Doc` 或 `Topic Doc`

### 更新策略

- `Task Doc`、`Topic Doc`、`Decision Doc`、`Daily Digest` 属于可更新对象
- `Snapshot Doc` 属于一次事件一个文档的创建型对象
- 所有可更新对象都应遵循：`list_documents` -> `get_document` -> merge -> `update_document`
- 新对象与更新对象统一优先使用结构化对象同步；运行时触发统一优先使用运行时事件同步

### 触发达成标准

只有真正执行了创建或更新动作，才算一次同步被触发。

以下情况不算完成同步：

- 只在流程里写了“此处应同步”
- 只生成了摘要但没有写入 KB
- 只计划了 checkpoint sync 但没有执行 MCP 工具

## 后续维护

这个目录是你的配置模板源。后续任何知识库相关配置更新，都应优先同步回这里，再分发到其他项目。

- **Cursor 侧扩展**（首选）：新增 skill / agent / 命令 / 钩子请放进 `.cursor/` 对应子目录，`setup.sh --cursor` 会整目录带下去。
- **OpenCode 侧**：`.opencode/` 目前仅保留历史参考，若需恢复 OpenCode 支持，请先补齐 `agents/` `snippets/` `skills/` 子目录，并同步修正 `AGENTS.md` 与 `README.md` 中标注为「历史参考」的章节。

## 当前模板默认值

- MCP API 地址：`http://localhost:4000/api/v1`
- 压缩快照目录：`Projects/<project>/Snapshots/`
- 日导航目录：`Daily/<YYYY>/<YYYY-MM>/`
- Knownbase 根目录：通过 `KNOWNBASE_ROOT` 或候选路径动态解析
- 工作流目录：`.specdev/specs/<slug>/`
- 设计系统落盘：`design-system/<slug>/MASTER.md`（生成于目标项目仓库）
- 视觉截图落盘：`screenshots/<phase>/`

## Workflow 选择建议

Cursor 在选择命令时，建议按下面规则判断：

| 命令 | 适用 | Phase 拆分 | 审查视角 |
|------|------|:--:|:--:|
| `/feature <desc>` | 复杂、多模块新功能 | 2-5 Phase + DAG | 四视角并行 |
| `/bugfix <desc>` | 单个 bug / 回归 | 单 Phase | 单视角 |
| `/brief <desc>` | 简单、< 3 文件改动 | 单 Phase | 单视角 |
| `/research <desc>` | 接手陌生模块的深度调研 | 不实施 | — |
| `/specify <desc>` | 先讨论需求再决定 | 不实施 | — |
| `/plan` | 已有需求，需设计方案 | 输出 DAG | — |
| `/implement` | HG-2 已通过，执行实施 | 单 Phase | 四视角并行 |
| `/status` | 随时查看进度与债务快照 | — | — |

补充判断：

- **选项不确定时优先选信息量最大的**：仓库现实与影响面还不明确 → `/research`；需求模糊 → `/specify`。
- **UI 工作流自动升级**：只要 `ui_relevant: true`，无论走哪个命令都会插入 HG-1.5、原型确认门禁、`reviewer-visual` 与强制视觉验证。
- **非极小任务默认包含审查与验证**：`implementer` 不能自己声明完成。
- **OpenCode 侧**：`/feature`、`/bugfix`、`/rebuild` 共用同一条 unified pipeline（详见上文 `.opencode/` 章节）。
