# Agent Role Matrix

## 11 个核心 Agent

当前推荐的 OpenCode Orchestrator 驱动工作流角色共 11 个：

- `orchestrator` (primary agent)
- `repo-explorer`
- `requirement-analyst`
- `program-planner`
- `task-planner`
- `solution-architect`
- `implementer`
- `reviewer`
- `validator`
- `knowledge-manager`
- `code-analyst`

用户只和 `orchestrator` 交互。其余 10 个 agent 作为 subagent 由 Orchestrator 通过 Task 工具调度。

这 10 个角色的设计目标不是"把流程拆得越细越好"，而是：

- 由 Orchestrator 统一调度和状态管理
- 先看清仓库现实
- 再收敛需求与方案
- 再实施
- 再审查
- 再验证
- 最后沉淀知识
- 在关键节点停下来等人类确认
- 对已有代码进行独立的深度分析

## 角色总表

### `orchestrator`

定位：主调度器，用户唯一交互入口

负责：

- 接收用户需求，选择合适的 pipeline
- 通过 Task 工具依次调度子 Agent
- 收集每个子 Agent 的摘要，维护全局状态
- 在 Human Gate 停下来，展示结构化摘要等待用户确认
- 维护 `specs/current-status.md` 以对抗上下文压缩
- 处理 reviewer/validator 的回路（最多 3 轮）
- 响应用户的干预指令（读文件、回退阶段、修正理解）

不负责：

- 不直接执行分析、实现、审查、验证等具体工作
- 不在上下文中保留完整文档（只保留摘要 + 文件路径）
- 不替代用户做关键决策

典型输出：

- `specs/current-status.md`（每阶段更新）
- 结构化阶段报告（在 Human Gate 呈现给用户）

### `repo-explorer`

定位：仓库侦察与现实建模

负责：

- 找出和任务最相关的模块、入口、调用链、依赖边界
- 识别影响面、已有约束、风险区、历史包袱
- 为后续分析、方案、实现提供“基于仓库事实”的输入

不负责：

- 不改代码
- 不直接做需求决策
- 不直接输出最终方案

典型输出：

- 相关模块
- 关键入口
- 影响面
- 风险与未知项
- 建议优先阅读文件

### `requirement-analyst`

定位：需求澄清与范围收敛（支持追加模式）

负责：

- 把用户意图转成可执行目标
- 明确 MVP、非目标、验收标准、开放问题
- 去掉模糊和过宽的表述
- 为高质量 `master-spec` 提供最强需求输入
- **支持两种模式**：create（首次创建）和 append（追加新需求到已有文档）

不负责：

- 不直接拆实现任务
- 不直接定技术方案
- 不直接改代码
- append 模式下不重写或重构已有需求

典型输出：

- 需求定义
- 范围边界
- 验收标准
- 待确认问题

### `program-planner`

定位：`master-spec` 生成/更新与系统级规划拆解

负责：

- 把大型产品或系统目标拆成顶层模块、能力域、交付阶段、里程碑
- 明确哪些模块先做、哪些后做、哪些需要先搭骨架
- 产出项目最重要的控制文档：`master-spec`
- **支持两种模式**：create（首次创建）和 update（增量追加新 phase）
- **提取子需求**：为每个新 phase 产出独立的 requirements 文档
- 为 `task-planner` 提供 program-level 边界，而不是直接下钻到代码实现

不负责：

- 不替代详细 task slicing
- 不直接做具体技术实现设计
- 不直接写代码
- 不修改或重排已完成的 phase

典型输出：

- `master-spec.md`（创建或更新）
- `phases/<phase-id>/requirements.md`（每个新 phase 的子需求）
- 模块地图
- 交付阶段
- 里程碑
- 关键依赖
- 推荐起始 phase 和起始 sub-spec

### `task-planner`

定位：phase-spec 与 sub-spec 拆分

负责：

- 把 `master-spec` 中指定 phase 落成当前 `phase-spec`
- 把当前阶段拆成有顺序的多个 `sub-spec`
- 指出当前最适合实现的 active `sub-spec`
- 始终读取 `master-spec.md` 获取全局上下文
- 始终读取 `phases/<phase-id>/requirements.md` 获取子需求

不负责：

- 不替代系统级拆分
- 不直接写代码

典型输出：

- `phase-spec.md`（当前 phase 的任务拆分）
- sub-spec 列表
- 当前推荐 sub-spec
- 阶段内依赖与顺序

### `solution-architect`

定位：技术方案与边界定义

负责：

- 为当前批准切片定义实现路径
- 说明模块边界、接口、数据流、约束、风险
- **设计 Validation Plan**：根据验收标准设计具体的测试场景（功能、边界、错误处理、回归），供 reviewer 和 validator 使用
- 让 `implementer` 有足够明确的执行边界

不负责：

- 不直接大规模写实现
- 不把方案扩成超出当前 slice 的系统重写

典型输出：

- 方案设计
- 关键决策
- **结构化 Validation Plan**（测试场景表、回归检查清单）
- 风险点
- 待确认项

### `implementer`

定位：按批准边界实施

负责：

- 只实现当前批准的 slice
- 修改必要代码、配置、脚本、测试
- **对 Validation Plan 中 functional/boundary 场景必须编写自动化测试**
- 记录改动、偏差、已知缺口、后续验证注意点

不负责：

- 不扩 scope
- 不私自改架构
- 不把顺手重构包装成"顺便做了"
- 不跳过写测试

典型输出：

- 实施总结
- 改动文件
- **自动化测试代码**
- 与原方案的偏差
- 已知缺口
- 给 reviewer / validator 的交接说明

### `reviewer`

定位：实现质量、逻辑正确性与测试覆盖审查

负责：

- 检查实现是否偏离需求和方案
- **逻辑正确性验证**：对照验收标准逐项检查代码是否正确实现
- 检查代码结构、命名、耦合、可维护性、一致性
- **测试覆盖度评估**：检查 implementer 是否编写了覆盖 Validation Plan 场景的测试
- **补充测试场景**：基于代码审查发现的边界条件，补充 Validation Plan 中遗漏的测试场景
- **提供验证命令**：列出 validator 应执行的具体验证命令
- 识别隐藏风险和应补修项

不负责：

- 不替代验证
- 不替代实现返工
- 不重新定义需求

典型输出：

- 逻辑正确性检查表
- 测试覆盖度评估
- must-fix / should-fix / optional improvements
- **补充测试场景**（供 validator 使用）
- **推荐验证命令**
- review verdict

### `validator`

定位：交付验证、测试用例执行与证据确认

负责：

- 依据验收标准验证功能是否成立
- **设计测试执行计划**：合并 sub-spec Validation Plan + reviewer 补充场景 + 自行发现的场景
- **逐项执行测试**：跑测试、构建、检查、回归验证、边界验证
- **编写验证脚本**：对没有自动化测试的场景，编写临时验证脚本
- **记录具体证据**：每个场景都有命令输出、测试结果等可追溯证据
- 区分"验证通过""部分验证""未验证"

不负责：

- 不把 code review 当成验证结论
- 不隐瞒失败检查
- 不在缺少证据时宣称 fully validated
- 不修改实现代码（只创建测试/验证脚本）

典型输出：

- **测试执行矩阵**（每个场景的来源、方法、结果、证据）
- 验收项对照表
- 验证脚本（临时）
- 结果（pass / partial / fail + 场景统计）
- 未验证项
- 风险与后续建议

### `knowledge-manager`

定位：知识沉淀与对象化同步

负责：

- 把关键需求、决策、任务过程、验证结果沉淀到知识库
- 选择合适对象：Task / Topic / Decision / Snapshot / Daily
- 控制同步粒度，避免噪音

不负责：

- 不替代实施或验证本身
- 不把所有内容挤进单一总文档

典型输出：

- task doc
- topic doc
- decision doc
- snapshot doc
- daily digest

### `code-analyst`

定位：独立的代码/模块深度分析，面向人类产出分析报告

负责：

- 分析代码仓或指定模块的整体架构、模块结构、层次关系
- 识别核心抽象、设计模式、是否一致
- 追踪主要数据流和状态管理方式
- 调查技术栈、外部依赖、外部服务集成
- 评估代码质量：优点、技术债、风险区、约定一致性
- 产出优先阅读的关键文件索引

不负责：

- 不改代码（edit 权限仅用于写入 specs/analysis/ 目录的分析报告和进度文件）
- 不做实现建议（除非用户明确要求）
- 不做需求分析或方案设计
- 不为下游 agent 服务（与 repo-explorer 的关键区别）

典型输出：

- 完整分析报告（面向人类可读）
- 架构概览
- 设计模式识别
- 数据流追踪
- 依赖关系图
- 代码质量观察
- 关键文件索引

## 推荐顺序

所有流程由 Orchestrator 调度。用户通过 pipeline 命令或自然对话触发。

### 统一 Pipeline (/feature, /bugfix, /rebuild)

`orchestrator -> repo-explorer -> requirement-analyst -> program-planner -> [KM checkpoint] -> 每个 phase: task-planner -> solution-architect -> [Human Gate] -> [KM checkpoint] -> implementer -> reviewer -> validator -> [KM checkpoint] -> [Human Gate]`

三个命令共用同一条 pipeline，区别仅在于传递给 requirement-analyst 的 intent 上下文。

### Idea 流程 (/idea)

`orchestrator -> repo-explorer -> requirement-analyst -> program-planner -> task-planner -> solution-architect -> knowledge-manager -> [Human Gate]`

### 小任务缩短版 (short flow)

`orchestrator -> repo-explorer -> implementer -> reviewer -> validator`

### 代码分析 (/analyze)

`orchestrator -> code-analyst -> knowledge-manager`

## 核心分工原则

- `orchestrator` 解决"谁来统一调度和保持状态"
- `repo-explorer` 解决"先别靠猜"
- `requirement-analyst` 解决"到底要做什么"
- `program-planner` 解决"整个系统先怎么分模块和阶段"
- `task-planner` 解决"先做哪一小块"
- `solution-architect` 解决"这一块该怎么做"
- `implementer` 解决"把它做出来"
- `reviewer` 解决"改得是否合理"
- `validator` 解决"结果是否成立"
- `knowledge-manager` 解决"别把过程和结论丢掉"
- `code-analyst` 解决"面对一份新代码，先弄清楚它是什么"

## 当前结论

当前不建议继续轻易增加更多通用 agent。

原因：

- 这 11 个角色（1 个调度器 + 10 个执行者）已经覆盖了大多数工程工作流
- 10 个执行者分为两类：9 个面向变更流水线（探索→需求→规划→设计→实现→审查→验证→沉淀），1 个面向独立分析（code-analyst）
- Orchestrator 的加入解决了之前手动调度的问题
- 再继续拆分会显著增加流程摩擦
- 目前最重要的是把边界执行稳定，而不是继续加角色数量
