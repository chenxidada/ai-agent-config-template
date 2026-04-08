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
├── opencode.jsonc                  # OpenCode MCP + plugin 配置
├── .mcp.json                       # Cursor / Claude Code / Windsurf MCP 配置
├── AGENTS.md                       # OpenCode / Claude Code 规则
├── .cursorrules                    # Cursor 规则（精简版）
├── .windsurfrules                  # Windsurf 规则（精简版）
├── knowledge-base-mcp.sh           # MCP 启动脚本，避免写死路径
├── setup.sh                        # 一键导入脚本
├── .opencode/                      # OpenCode 模板目录（统一扩展入口）
│   ├── README.md                   # .opencode 目录约定
│   ├── agents/                     # staged workflow agents
│   ├── hooks/                      # runtime trigger docs / automation helpers
│   ├── plugins/                    # OpenCode runtime plugins
│   ├── snippets/                   # reusable task snippets
│   ├── templates/                  # prompt / output templates
│   └── skills/
│       └── conversation-sync-kb/   # OpenCode 技能：压缩摘要同步知识库
└── README.md
```

## 设计说明

这套模板只做一件事：

- 给 AI 工具接入 `knowledge-base` MCP
- 统一知识库工作流
- 在上下文压缩、研究结束、任务收尾时，把结果沉淀到知识库

不再保留和知识库无关的远程构建、刷写、部署技能。

## 建议的 `.opencode/` 目录规范

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

其中 `knowledge-manager` 用于把关键需求、方案、实现、验证结果持续同步到当前知识库，并在关键检查点做增量沉淀。

当前模板还包含一个 OpenCode runtime plugin，用于把压缩触发、手动同步请求等场景真正接到 MCP 同步流程上。

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

1. 复制配置文件
2. 同步模板中的整个 `.opencode/` 目录
3. 复制 `knowledge-base-mcp.sh`
4. 将 `opencode.jsonc` 加入 `.gitignore`

### 方法二：手动复制

```bash
cd /your/project
cp /path/to/ai-agent-config-template/opencode.jsonc .
cp /path/to/ai-agent-config-template/.mcp.json .
cp /path/to/ai-agent-config-template/AGENTS.md .
cp /path/to/ai-agent-config-template/.cursorrules .
cp /path/to/ai-agent-config-template/.windsurfrules .
cp /path/to/ai-agent-config-template/knowledge-base-mcp.sh .
cp -R /path/to/ai-agent-config-template/.opencode .
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

如果你后续要新增 OpenCode 的 skill、agent 配置、额外模板文件，也建议都放进这里的 `.opencode/` 下，这样 `setup.sh` 会一起同步出去。

## 当前模板默认值

- MCP API 地址：`http://localhost:4000/api/v1`
- 压缩快照目录：`Projects/<project>/Snapshots/`
- 日导航目录：`Daily/<YYYY>/<YYYY-MM>/`
- Knownbase 根目录：通过 `KNOWNBASE_ROOT` 或候选路径动态解析

## Workflow 选择建议

OpenCode 在选择 workflow 时，建议按下面规则判断：

- `/feature <desc>` — 新功能开发，走统一 pipeline（unified-pipeline）
- `/bugfix <desc>` — Bug 修复、回归、根因排查，走统一 pipeline
- `/rebuild <desc>` — 架构级迭代、系统重建，走统一 pipeline
- `/idea <desc>` — 想法探索，停在 solution-architect 之后，不进入实现
- `/analyze <desc>` — 代码库/模块分析，产出人类可读报告，不做代码修改

补充判断：

- `/feature`、`/bugfix`、`/rebuild` 共用同一条 unified pipeline，以 intent 标签区分范围和侧重点
- 如果仓库现实、影响面、根因还不明确，应优先选择会从 `repo-explorer` 开始的 staged workflow，而不是直接实现
- 非极小任务，默认都应包含 `reviewer` 和 `validator`
