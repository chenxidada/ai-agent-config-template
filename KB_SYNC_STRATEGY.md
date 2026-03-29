# KB Sync Strategy

## 核心定义

当前模板侧知识同步策略已经统一为两类高层动作：

- 运行时事件同步
- 结构化对象同步

不再让 Agent 在多个旧工具之间做模糊选择。

## 1. 什么时候触发

统一三类触发：

- `compression`
  - context compression
  - reset
  - handoff
- `checkpoint`
  - requirement
  - architecture
  - implementation
  - validation
  - debugging
- `manual`
  - 用户明确要求“总结并同步”“提炼并同步”“沉淀到知识库”

## 2. 触发后调用什么

### 运行时事件

使用运行时事件同步。

适用于：

- compression / reset / handoff
- workflow 阶段完成
- 手动 summarize-and-sync 请求

### 结构化对象

使用结构化对象同步。

适用于：

- 明确知道要写入某个任务、主题、决策、快照或当日记录对象
- 需要稳定 objectKey、路径、merge 语义时

### 路径与状态辅助

用：

- 路径解析工具
- 对象状态查询工具

## 3. 对象模型

- task
- topic
- decision
- snapshot
- daily

命名规范：

- `[task:<task-id>] <project> - <task-name>`
- `[topic:<topic-key>] <project> - <topic-name>`
- `[decision:<decision-key>] <project> - <decision-name>`
- `[snapshot:YYYYMMDD-HHmmss] <project> - <label>`
- `[daily] YYYY-MM-DD - <project>`

## 4. 默认映射

- compression / reset / handoff -> snapshot + daily
- requirement -> topic，必要时补 decision
- architecture -> decision，必要时补 topic
- implementation -> task
- validation -> task
- debugging -> task，必要时补 topic
- manual -> 根据内容选择最合适对象

## 5. OpenCode 侧实现

OpenCode 模板当前通过这些文件落实：

- `AGENTS.md`
- `.opencode/agents/knowledge-manager.md`
- `.opencode/snippets/kb-sync-sop.md`
- `.opencode/plugins/kb-sync-runtime.mjs`
- `.opencode/hooks/kb-sync-runtime-plugin.md`

其中：

- runtime plugin 负责压缩触发和手动触发提示增强
- workflow snippets 负责阶段触发
- knowledge-manager 负责把触发真正执行成 KB 写入

## 6. 完成标准

只有真正执行了 MCP 写入，才算同步完成。

以下都不算完成：

- 只生成摘要
- 只说“这里应该同步”
- 只在文档中声明 checkpoint 已同步
- 没有执行真实的高层同步写入动作

## 7. 最终原则

- 运行时事件同步负责触发语义
- 结构化对象同步负责落库语义
- 路径解析工具负责路径语义
- 对象状态查询工具负责状态确认

## 8. 内容语言规则

- 模板库中默认要求：知识库同步内容、总结、快照、daily continuity 说明默认使用中文
- 只有用户明确要求英文或项目本身有固定语言约束时，才切换为其他语言

## 9. 渲染友好规则

- 默认遵循 `.opencode/templates/kb-rendering-guideline.md`
- 少用内联代码包裹工具名，避免正文出现大段代码样式
- 少把一条 bullet 写得过长，优先拆成短句和短列表
- 知识库正文优先写成可读说明，不写成工具调用手册

这就是模板侧最终生效的 KB 同步策略。
