# Knownbase 写入链路说明

## 当前官方方案

这套配置模板现在统一采用一条官方写入链路：

- 所有知识同步都通过 `knowledge-base` MCP 完成
- `MCP` 是唯一官方读写入口
- 不再把本地 HTTP 脚本作为模板默认写入方案
- 统一使用高层 MCP sync tools，而不是旧的 daily-only sync helper

换句话说，当前模板对“写知识库”的定义是：

- agent 产出结构化内容
- agent 通过 MCP 工具解析目录、查找文档、读取旧内容、创建或更新文档
- durable knowledge 以统一对象模型落到 Knownbase

## 官方工具边界

### 高层同步首选

- 路径解析工具
- 结构化对象同步
- 运行时事件同步
- 对象状态查询

这组工具负责：

- 解析逻辑路径
- 同步结构化知识对象
- 同步运行时事件
- 查询对象同步状态

## 统一对象模型

### 1. Task Doc

- 路径：`Projects/<project>/Tasks/`
- 标题：`[task:<task-id>] <project> - <task-name>`
- 用途：记录一个具体任务或一次工作流运行的过程和结果
- 更新方式：可更新

### 2. Topic Doc

- 路径：`Projects/<project>/Topics/`
- 标题：`[topic:<topic-key>] <project> - <topic-name>`
- 用途：记录某个长期主题的知识积累
- 更新方式：可更新

### 3. Decision Doc

- 路径：`Projects/<project>/Decisions/`
- 标题：`[decision:<decision-key>] <project> - <decision-name>`
- 用途：记录关键决策、权衡和影响
- 更新方式：可更新

### 4. Snapshot Doc

- 路径：`Projects/<project>/Snapshots/`
- 标题：`[snapshot:YYYYMMDD-HHmmss] <project> - <label>`
- 用途：记录压缩、reset、handoff 等时间点快照
- 更新方式：只创建，不覆盖旧快照

### 5. Daily Digest

- 路径：`Daily/<YYYY>/<YYYY-MM>/`
- 标题：`[daily] YYYY-MM-DD - <project>`
- 用途：记录当天执行连续性、导航信息、阻塞项和下一步
- 更新方式：同项目同日期唯一一份，可更新

## 事件到对象的映射

- 需求澄清完成 -> `Topic Doc` 或 `Decision Doc`
- 架构结论形成 -> `Decision Doc`，必要时补 `Topic Doc`
- 实现里程碑完成 -> 更新 `Task Doc`
- 验证完成 -> 更新 `Task Doc`
- 重要排障结论 -> `Task Doc` 或 `Topic Doc`
- 压缩 / reset / handoff -> 新建 `Snapshot Doc`，并更新 `Daily Digest`

这里最重要的统一规则是：

- 压缩事件默认写 `Snapshot Doc`
- 当天恢复导航默认写 `Daily Digest`
- 不再把压缩摘要直接写成一个固定的 daily 正文

## 标准写入流程

### A. 创建型对象

适用于：

- `Snapshot Doc`
- 任何首次创建的 `Task / Topic / Decision / Daily`

标准流程：

1. 用路径解析工具解析目标目录
2. 生成符合规范的对象输入
3. 用结构化对象同步创建对象

### B. 更新型对象

适用于：

- 已存在的 `Task Doc`
- 已存在的 `Topic Doc`
- 已存在的 `Decision Doc`
- 已存在的 `Daily Digest`

标准流程：

1. 用对象状态查询工具查看对象状态
2. 准备对象内容和元数据
3. 用结构化对象同步执行 create/update/merge

禁止的做法：

- 不读取旧文档直接覆盖
- 把无关内容塞进同一个对象
- 用一次性总结替代结构化对象更新

## 压缩同步专用流程

当发生 context compression / reset / handoff 时，标准流程如下：

1. 生成本轮结构化摘要
2. 在 `Projects/<project>/Snapshots/` 中创建新的 `Snapshot Doc`
3. 解析 `Daily/<YYYY>/<YYYY-MM>/`
4. 查找当天的 `Daily Digest`
5. 如果存在，先读取后合并，再更新
6. 如果不存在，创建新的 `Daily Digest`
7. 如果本轮产生长期结论，再补 `Decision Doc` 或 `Topic Doc`

## 目录解析规则

目录定位必须遵循“逻辑路径解析”，不能只按一个裸名字查找。

正确做法：

- 先解析 `Projects` 或 `Daily`
- 再解析 `<project>` 或 `<YYYY>/<YYYY-MM>`
- 最后解析对象子目录，如 `Tasks`、`Topics`、`Decisions`、`Snapshots`

禁止做法：

- 写死 `folderId`
- 只按一个裸文件夹名盲查

## 推荐元数据

每个结构化对象建议包含这些字段：

- `objectType`
- `objectKey`
- `project`
- `trigger`
- `sourceType: ai-chat`
- `sourceTool: opencode`
- `updatedAt`
- `relatedTaskId` 或相关对象引用

## 迁移后的核心结论

- 当前模板的官方知识写入方案已经统一为 MCP only
- 结构化对象同步是结构化对象的主入口
- 运行时事件同步是运行时触发的主入口
- 路径解析和对象状态查询提供辅助能力
- 压缩事件的标准动作是：通过运行时事件同步创建 Snapshot Doc 并更新 Daily Digest
