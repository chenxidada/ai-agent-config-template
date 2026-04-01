# Orchestrator 编排架构设计总结

## 1. 目标

用户只跟一个 OpenCode 主 Session（Orchestrator）交互。Orchestrator 自动调度 10 个子 Agent 完成完整的软件工程工作流，在关键节点停下来等待人类确认，支持用户随时干预修正。

## 2. 核心架构：双向摘要 + 文件落盘 + 人为干预

```
                    用户
                     ↕ (自然对话 + 人为干预修正)
              ┌──────────────┐
              │ Orchestrator │ ← 只持有：摘要 + 文件路径索引 + 当前状态
              └──────┬───────┘
                     │ Task 工具调度
         ┌───────────┼───────────┐
         ↓           ↓           ↓
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │ Agent A │ │ Agent B │ │ Agent C │
    └────┬────┘ └────┬────┘ └────┬────┘
         ↓           ↓           ↓
    output-A.md  output-B.md  output-C.md
         └───────────┼───────────┘
              specs/ 统一目录
              (共享外部记忆)
```

### 2.1 向下传递策略（选择性传递）

Orchestrator 给每个子 Agent 的 dispatch prompt 只包含：

- 上游 Agent 的**摘要**（3-5 句）
- 用户的相关决策
- **完整文件的路径**（告诉子 Agent 自己去读）
- **输出文件路径**（告诉子 Agent 写到哪里）
- 明确指令：只返回摘要，不返回全文

每个 Agent 的 Input 来源：

| Agent | 接收的摘要 | 需要自行读取的文件 |
|-------|-----------|-------------------|
| repo-explorer | 用户需求 | - |
| requirement-analyst | repo-explorer 摘要 | specs/exploration/repo-exploration.md |
| program-planner | requirement 摘要 | specs/requirements/requirements.md, specs/exploration/repo-exploration.md |
| task-planner | requirement 摘要 | specs/master-spec.md, specs/requirements/requirements.md |
| solution-architect | task-planner 摘要 + 推荐 sub-spec | specs/phases/\<phase\>/phase-spec.md |
| implementer | 上游 agent 摘要 | **由 Orchestrator dispatch prompt 指定**（全流程读 sub-spec.md + solution-design.md；bugfix 读 requirements.md + task-plan.md） |
| reviewer | implementer 摘要 | implementation-summary.md, sub-spec.md |
| validator | implementer 摘要 + reviewer 摘要 | implementation-summary.md, review-report.md, sub-spec.md |
| knowledge-manager | 阶段摘要 | 由 Orchestrator 指定的对应阶段 spec 文件 |
| code-analyst | 用户分析请求（scope + focus） | - （自行探索目标代码） |

### 2.2 向上返回策略（摘要 + 文件路径）

每个子 Agent 完成后：

1. 将**完整输出**按模板格式写入 specs/ 对应目录
2. **返回给 Orchestrator 的只有**：
   - 3-5 句核心结论摘要
   - 产出文件的路径
   - 需要下一阶段关注的关键风险或开放问题
   - 是否需要人类确认的标记

返回示例：

```
## requirement-analyst 完成

**摘要**: 确认 MVP 范围为 CSV/JSON 双格式导出，限制为当前用户自己的数据。
验收标准 5 条。有 2 个开放问题需要用户确认（权限模型、大文件分页策略）。

**产出文件**: specs/requirements/requirements.md
**需要确认**: 是 (2 个开放问题)
**关键风险**: 大数据量导出的性能问题
```

## 3. 统一输出目录结构

```
<project-root>/
└── specs/
    ├── master-spec.md                              ← program-planner 产出
    ├── current-status.md                           ← Orchestrator 维护
    ├── exploration/
    │   └── repo-exploration.md                     ← repo-explorer 产出
    ├── requirements/
    │   └── requirements.md                         ← requirement-analyst 产出
    ├── analysis/
    │   ├── code-analysis-full.md                   ← code-analyst 产出（全仓）
    │   └── code-analysis-<scope-slug>.md           ← code-analyst 产出（指定范围）
    ├── phases/
    │   └── <phase-id>/
    │       ├── phase-spec.md                       ← task-planner 产出
    │       └── slices/
    │           └── <sub-spec-id>/
    │               ├── sub-spec.md                 ← solution-architect 产出
    │               ├── solution-design.md          ← solution-architect 产出
    │               ├── implementation-summary.md   ← implementer 产出
    │               ├── review-report.md            ← reviewer 产出
    │               └── validation-report.md        ← validator 产出
    └── task-plan/
        └── task-plan.md                            ← task-planner 产出
```

## 4. Orchestrator 状态管理模型

### 4.1 三层模型

**第一层：持久化状态文件**（specs/current-status.md）

Orchestrator 在每个阶段完成后更新此文件，记录 pipeline 类型、当前阶段、已完成阶段摘要表、用户决策历史、回路追踪、下一步行动。这是对抗上下文压缩的核心机制。

**第二层：对话中的工作记忆**

Orchestrator 上下文中只保留：
- 用户原始需求
- 最新 2-3 个 Agent 返回的摘要
- 当前正在处理的阶段上下文
- 用户最近的确认/反馈

**第三层：可按需读取的完整文件**

specs/ 目录下所有文件，Orchestrator 和子 Agent 都可以随时读取。

### 4.2 Compaction 恢复机制

当上下文压缩发生后，Orchestrator 的第一个动作是：

1. 读取 specs/current-status.md 重建工作状态
2. 识别当前所在阶段
3. 向用户宣布恢复状态
4. 继续执行

## 5. Orchestrator 用户交互协议

### 5.1 输入分类

每条用户消息先分类再处理：

| 类别 | 条件 | 处理 |
|------|------|------|
| A: Pipeline 命令 | 用户用了 /feature, /bugfix, /idea, /rebuild, /fullflow, /analyze | 直接走对应 pipeline |
| B: 工程任务 | 用户描述需要分析/设计/实现/调试的工作 | 走决策树选 pipeline，向用户确认后启动 |
| C: 非工程输入 | 提问、解释、文档等 | 直接回答，不启动 pipeline |

### 5.2 Pipeline 选择决策树（Category B）

按优先级顺序匹配：

1. Bug/错误/异常 → **bugfix**
2. 新功能/新能力 → **feature**
3. 探索/分析/评估（不含实现）→ **idea**
4. 理解/分析现有代码或模块 → **analyze**
5. 系统重建/大规模重写 → **rebuild**
6. 跨域大任务/不明确任务 → **fullflow**
7. 非常小的单点修改 → **short flow**
8. 以上都不匹配 → 尝试**默认倾向规则**
9. 仍无法判断 → **结构化三问澄清**

### 5.3 默认倾向规则

对常见模糊输入模式，给出默认推荐 + 向用户确认：

| 用户表述模式 | 默认倾向 |
|-------------|---------|
| "帮我看看/分析一下这个代码/模块/仓库" | analyze |
| "帮我分析一下这个想法/方案/需求" | idea |
| "X 不太对 / X 有问题" | bugfix |
| "优化/重构/整理一下 X" | feature |
| "帮我改一下 X" / "把 X 改成 Y" | short flow |
| "我想重新做 X" / "X 需要重写" | rebuild |

规则：始终宣布选择和理由，等用户确认，猜错的成本低（有 Human Gate 兜底）。

### 5.4 结构化三问澄清（最终兜底）

当决策树和默认倾向都无法判断时，向用户提问三个维度：

1. **目标**：分析报告 / 代码改动 / 完整计划+实现 / 自由描述
2. **范围**：1-2 个文件 / 一个模块 / 跨模块 / 自由描述
3. **深度**：快速看一眼 / 结构化分析 / 完整工程流程 / 自由描述

用户可以选预设选项、自由文本回答、或混合使用。

## 6. Human Gate 设计

### 6.1 两个固定 Gate

- **Gate 1 - 进入实现前**：规划和设计阶段完成后停下，呈现结构化摘要，等用户确认
- **Gate 2 - 完成一个 sub-spec 后**：报告结果，推荐下一个 sub-spec，等用户确认

### 6.2 Human Gate 与 knowledge-manager checkpoint 的顺序

统一规则：**先 Human Gate，再 knowledge-manager checkpoint**。

理由：用户确认后再同步到知识库，同步的是已确认的内容，价值更高。

### 6.3 结构化确认格式

```markdown
## 阶段报告: <阶段名>

| 阶段 | Agent | 状态 | 产出文件 |
|------|-------|------|---------|
| ...  | ...   | ...  | ...     |

## 关键结论
- ...

## 需要你的确认
→ 回复 "继续" 进入下一阶段
→ 回复修改意见
→ 回复 "读 <文件路径>" 查看完整文档后再决定
```

## 7. 人为干预修正机制

三种干预模式，均不需要特殊技术机制，基于自然对话：

### 7.1 直接指令修正

用户随时可以说"去读 specs/xxx.md 重新理解"，Orchestrator 执行读取并更新理解。

### 7.2 阶段确认时的修正

在 Human Gate，用户可以要求 Orchestrator 读取完整文件后重新给出更准确的摘要。

### 7.3 强制重跑某个阶段

用户可以要求回退到某个 Agent 重新执行，Orchestrator 重新调度该 Agent。

### 7.4 Pipeline 进行中的意图切换

如果用户在 pipeline 进行中提出不相关的请求，Orchestrator 先询问是否暂停当前 pipeline，暂停时更新 current-status.md 记录状态。

## 8. Orchestrator 主动读取文件的规则

默认不读取完整文件，以下场景必须主动读取：

| 场景 | 触发条件 | 读取内容 |
|------|---------|---------|
| Compaction 恢复 | 上下文压缩发生后 | specs/current-status.md |
| 回路处理 | reviewer 返回 must-fix | review-report.md + sub-spec.md |
| 阶段冲突 | 子 Agent 报告与上游设计冲突 | 相关的 spec 文件 |
| 用户要求 | 用户明确指定 | 用户指定的文件 |
| 调度决策不确定 | 不确定传什么给下游 | 上游的 spec 文件 |
| 分析报告呈现 | code-analyst 完成后需要摘要 | specs/analysis/code-analysis-*.md |

## 9. 通用规则（适用于所有 Pipeline）

以下规则集中定义在 `orchestrator.md` 中，各 pipeline snippet 不重复。

### 9.1 回路处理

| reviewer 判定 | 处理方式 |
|--------------|---------|
| must-fix | 自动回到 implementer 修复 → 重新 review，最多 3 轮，超出升级给用户 |
| should-fix | 报告给用户，用户决定是否修复 |
| pass | 进入 validator |

| validator 判定 | 处理方式 |
|---------------|---------|
| fail | 自动回到 implementer 修复 → 重新验证，最多 3 轮，超出升级给用户 |
| partial pass | 报告给用户，用户决定是否接受 |
| pass | 进入下一阶段 |

回路追踪：每次循环更新 current-status.md 的 Loop Tracking 区域。升级给用户时呈现：原始问题、每轮尝试内容、仍未解决的原因。

### 9.2 knowledge-manager checkpoint 门控

- checkpoint 阶段在 sync 实际执行并返回成功/失败后才算完成
- sync 失败则重试一次；仍失败则报告给用户并继续 pipeline（不无限阻塞）

### 9.3 子 Agent 执行异常

报告给用户，等待指令。不猜测、不自动恢复。

## 10. 工作流切换

### 10.1 Command 快捷入口

| 命令 | Pipeline | 适用场景 |
|------|----------|---------|
| /feature \<描述\> | feature-pipeline | 新功能开发 |
| /bugfix \<描述\> | bugfix-pipeline | Bug 修复 |
| /idea \<描述\> | idea-to-mvp | 想法探索（不含实现）|
| /rebuild \<描述\> | rebuild-knownbase-flow | 系统重建 |
| /fullflow \<描述\> | requirements-to-implementation | 完整 13 阶段流程 |
| /analyze \<描述\> | analyze-pipeline | 代码仓/模块分析，产出人类可读报告 |
| (自动) | short flow | 非常小的单点修改 |

### 10.2 自动判断

如果用户直接在主 Session 输入需求（不用 Command），Orchestrator 通过 Interaction Protocol 的决策树 → 默认倾向规则 → 结构化澄清，逐层收敛到一个 pipeline，并向用户确认选择。

### 10.3 Short Flow

Pipeline: `repo-explorer → implementer → reviewer → validator`

适用条件：改动限于 1-2 个文件、指令明确、无需需求澄清或架构设计、影响面明显有限。

Short flow 没有单独的 snippet 文件，阶段定义内联在 orchestrator.md 中。如果 repo-explorer 发现任务比预期大，升级到完整 pipeline。

## 11. 子 Agent 定义规范

### 11.1 YAML Frontmatter

所有子 Agent 都必须有 YAML frontmatter，包含 `description`、`mode: agent`、`permission`。

### 11.2 权限模型

| Agent | bash | edit | task |
|-------|------|------|------|
| repo-explorer | allow | deny | deny |
| requirement-analyst | deny | deny | deny |
| program-planner | deny | deny | deny |
| task-planner | deny | deny | deny |
| solution-architect | deny | deny | deny |
| implementer | allow | allow | deny |
| reviewer | allow | deny | deny |
| validator | allow | deny | deny |
| knowledge-manager | deny | deny | deny |
| code-analyst | allow | deny | deny |

原则：
- 只有 implementer 有 edit 权限（需要改代码）
- repo-explorer、reviewer、validator 有 bash 权限（需要探索仓库/看 diff/跑测试）
- 所有子 agent 的 task 都是 deny（不能调度其他 agent，只有 Orchestrator 能调度）
- knowledge-manager 通过 MCP 工具写入知识库，不需要 bash 或 edit

### 11.3 信息流合同

每个子 Agent 的 Input 部分应描述"由 Orchestrator dispatch prompt 指定上游文件"，而非硬编码固定文件路径。这样同一个 agent 可以在不同 pipeline 中接收不同的上游文件。

## 12. 规则权威性层级

当不同文件的规则有冲突时，按以下优先级：

1. **orchestrator.md** — 通用规则（回路处理、门控、升级、用户交互协议）的唯一权威来源
2. **pipeline snippet** — 各 pipeline 阶段序列和 dispatch 参数的权威来源
3. **agent 定义文件** — 各 agent 职责和返回格式的权威来源
4. **command 文件** — pipeline 触发的入口，引用 snippet 文件

snippet 只负责"这个 pipeline 有哪些阶段、每个阶段传什么"，不重复 orchestrator.md 中的通用规则。

## 13. 并发策略

当前阶段：严格串行。后续可优化的并发场景：
- repo-explorer 和 requirement-analyst 部分并行
- reviewer 和 validator 并行

## 14. 设计原则总结

1. **Orchestrator 上下文保持轻量** — 只持有摘要和文件索引，不持有完整文档
2. **specs/ 目录是共享外部记忆** — 所有参与方（Orchestrator、子 Agent、用户）都可直接访问
3. **子 Agent 自行读取所需文件** — 不依赖 Orchestrator 转发全文
4. **current-status.md 是持久化状态** — 对抗上下文压缩的核心机制
5. **用户始终可以干预** — 指定读文件、回退阶段、修正理解，降低对 Orchestrator 自动判断的依赖
6. **Human Gate 保留控制权** — 实现前确认、sub-spec 完成后确认
7. **先确认再同步** — Human Gate 在 knowledge-manager checkpoint 之前，确保同步的是用户已确认的内容
8. **通用规则单点定义** — 回路/门控/升级规则只在 orchestrator.md 中定义一次，snippet 不重复
9. **子 Agent 权限最小化** — 每个 agent 只获得其职责所需的最小权限集
