---
name: conversation-sync-kb
description: 对话压缩时自动同步摘要到个人知识库，创建 snapshot 并更新 daily，确保每次上下文压缩都不丢失关键信息。
---

## 对话压缩同步知识库

### 触发时机

**每次对话上下文被压缩（conversation compression / context window reset）时，必须执行此流程。**

这是一条强制规则，不需要用户额外提醒。

### 流程

1. **获取已有快照**：调用 `knowledge-base_get_sync_object_status`（objectType: `snapshot`, project: 当前项目名, objectKey: 项目名）检查是否已有快照文档
   - 如果存在，通过 `knowledge-base_get_document` 读取其完整内容
   - 如果不存在，跳到下一步
2. **精炼项目快照**：将压缩后的 Goal block（Goal / Instructions / Discoveries / Accomplished / Relevant files）与已有快照内容合并精炼：
   - 保留长期有效的上下文（项目目标、架构决策、累积成果）
   - 更新当前状态和进度
   - 移除已过时的信息
   - 输出为完整的 Markdown 文档（不是增量片段）
3. **同步快照**：调用 `knowledge-base_sync_runtime_event`
   - `triggerType`：`compression`
   - `stage`：`compression` / `reset` / `handoff`
   - `project`：当前项目名
   - `summary`：精炼后的完整项目快照内容
   - `objectKey`：项目名（确保同一项目只有一个快照）
4. **同步 daily**：上述调用默认也会更新当天的 daily 文档
5. **必要时补结构化对象**：如果本轮压缩产出长期结论，再调用 `knowledge-base_sync_kb_object` 同步 `decision` 或 `topic`
6. **确认同步成功**：打印同步结果告知用户

### 文档格式

```markdown
# <project> - 项目快照

> 最后更新: <ISO timestamp> | 会话: <session-id>

## 项目目标

（长期项目目标和核心方向）

## 架构决策

（重要的架构和技术选型决策）

## 当前状态

（进行中的工作、最新进展）

## 累积成果

（已完成的重要里程碑）

## 待办事项

- [ ] 下一步要做的事情

## 关键文件

（项目核心文件路径）
```

### 知识库配置

| 配置项         | 值                                                |
| -------------- | ------------------------------------------------- |
| 运行时事件工具 | `knowledge-base_sync_runtime_event`               |
| snapshot 路径  | `Projects/<project>/Snapshots/`（每项目一个文档） |
| daily 路径     | `Daily/<YYYY>/<YYYY-MM>/`                         |
| sourceType     | `ai-chat`                                         |

### summary 字段质量规范（强制）

`summary` 必须包含具体技术内容，禁止统计性泛化描述。

**要求：** 写明具体文件名/函数名/架构变更、关键决策及原因、重要发现、下一步 TODO。用 Markdown 结构化。

**禁止：** "共执行 N 次工具调用"、"修改了几个文件"、"进行了优化" 等不含技术细节的描述。

**示例：**

- ✅ 重构 `pdf.service.ts`（1087→7 子服务），新增 `LlmCallSpec` 统一 AI 调用
- ❌ 对代码进行了修改和优化

### 注意事项

- 摘要要包含足够上下文，让未来的对话能快速恢复工作状态
- 包含具体的文件路径、行号、命令等可操作信息
- 包含未完成的待办事项，方便下次继续
- 避免冗余，突出关键结论和决策
- 压缩事件的默认结果应是：更新项目唯一的 `snapshot` 对象并更新当天的 `daily` 对象
