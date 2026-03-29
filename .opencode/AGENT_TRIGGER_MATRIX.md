# Agent Trigger Matrix

## 目标

这份表不是为了让每个任务都走完整 9-agent 流程，而是为了帮助你快速判断：

- 这个任务该走全流程还是短流程
- 哪些 agent 必须出现
- 哪些 agent 可以按条件跳过

## 默认规则

### 走完整流程的情况

默认使用完整流程：

`repo-explorer -> requirement-analyst -> program-planner -> task-planner -> solution-architect -> human confirmation -> implementer -> reviewer -> validator -> knowledge-manager`

适用条件：

- 需求还不够清楚
- 影响面不明确
- 需要先拆 slice
- 需要先形成 `master-spec / phase-spec / sub-spec`
- 需要先定方案
- 任务预计跨多个文件或模块
- 任务会影响接口、数据结构、流程边界、系统行为

### 走短流程的情况

可以使用短流程：

`repo-explorer -> implementer -> reviewer -> validator -> knowledge-manager`

适用条件：

- 目标非常明确
- 不需要重新做需求澄清
- 不需要正式任务拆解
- 不需要额外方案设计
- 改动范围较小且影响面可控

## Agent 触发条件

### `repo-explorer`

默认：几乎总是触发。

必须触发：

- 新仓库
- 不熟悉的模块
- Bug 根因不明
- 需要判断影响面

可弱化处理：

- 已经非常熟悉的单文件小改

### `requirement-analyst`

触发条件：

- 用户需求有歧义
- 需要收敛 MVP
- 需要明确验收标准
- 任务里混有目标、实现想法、限制，尚未整理干净

可跳过：

- 已经是非常清楚的工程指令
- 例如“修这个明确报错”“给这个接口补一个字段”

### `task-planner`

触发条件：

- 任务需要切片
- 任务有多个阶段或子模块
- 需要决定先做哪一块
- 需要减少一次性实现风险

可跳过：

- 单个小修复
- 单个非常明确的最小功能点

### `program-planner`

触发条件：

- 任务是系统级或产品级重建
- 需要先做模块拆分和阶段规划
- 任务跨多个能力域、子系统、前后端或基础设施层
- 需要决定先搭骨架还是先实现业务 slice
- 需要一个可反复确认的 `master-spec`

可跳过：

- 普通 feature
- 小型 bug fix
- 单一 slice 的迭代任务

补充：

- 对于需要反复确认方向的大项目，`program-planner` 应视为强制角色

### `solution-architect`

触发条件：

- 需要先定技术边界
- 涉及接口、数据结构、组件边界、集成方式
- 存在多种实现路线，需要先选方案
- 仓库现实和目标之间有设计决策要做

可跳过：

- 非结构性的小修复
- 实现路径已经非常明确且低风险

### `implementer`

默认：只要进入执行，就触发。

必须触发：

- 需要改代码、脚本、配置、测试

不应单独裸奔：

- 在复杂任务里，不应绕过前面的上下文和边界定义直接开始

### `reviewer`

默认：建议总是触发。

尤其应该触发：

- 改动跨多个文件
- 有结构性变更
- 有可维护性风险
- 任务容易 scope drift

可简化：

- 极小改动时，review 可以很轻，但最好不要完全没有

### `validator`

默认：只要有实现，就应触发。

必须触发：

- 代码改动
- 配置改动
- 接口行为改动
- 可能引发回归的修复

不可跳过：

- 任何会被视作“完成”的实现任务

### `knowledge-manager`

默认：重大阶段结束时自动触发；压缩 / reset / handoff 时强制触发。

必须触发：

- 有稳定结论
- 有决策
- 有实施结果
- 有验证结果
- 有压缩 / handoff / reset

触发后必须执行的动作：

- 不是只说“这里应该同步”
- 必须真的执行 MCP 写入
- checkpoint 未完成同步前，不算该阶段真正结束

可简化：

- 很小的、没有长期价值的临时操作

## 常见任务对应建议

### 新功能

建议流程：

- `repo-explorer -> requirement-analyst -> task-planner -> solution-architect -> implementer -> reviewer -> validator -> knowledge-manager`
- 如果是系统级任务，升级为：
- `repo-explorer -> requirement-analyst -> program-planner -> task-planner -> solution-architect -> human confirmation -> implementer -> reviewer -> validator -> knowledge-manager`

### Bug 修复

建议流程：

- 根因不明：完整偏长流程
- 根因明确的小修：短流程

推荐：

- `repo-explorer -> requirement-analyst -> task-planner -> implementer -> reviewer -> validator -> knowledge-manager`

### 单点小修

建议流程：

- `repo-explorer -> implementer -> reviewer -> validator`

如有长期价值，再补：

- `knowledge-manager`

如果发生压缩 / reset / handoff：

- 即使是小任务，也必须触发 `knowledge-manager` 同步 `Snapshot Doc` 和 `Daily Digest`

### 重构

建议流程：

- `repo-explorer -> requirement-analyst -> task-planner -> solution-architect -> implementer -> reviewer -> validator -> knowledge-manager`
- 如果是系统级重构，建议加入 `program-planner`

### 仅分析，不写代码

建议流程：

- `repo-explorer -> requirement-analyst`

如结论重要，再补：

- `knowledge-manager`

### 重建 Knownbase / 复杂系统迭代

建议流程：

- 全流程，不建议省略 `task-planner`、`solution-architect`、`reviewer`、`validator`
- 对于系统重建，不建议省略 `program-planner`

## 最终判断口诀

- 不清楚先 `repo-explorer`
- 不清楚要做什么先 `requirement-analyst`
- 太大、太像系统工程先 `program-planner`
- 太大先 `task-planner`
- 有设计分歧先 `solution-architect`
- 要动手就 `implementer`
- 改完先过 `reviewer`
- 想交付必须过 `validator`
- 有价值结果就立刻交给 `knowledge-manager` 做真实同步
