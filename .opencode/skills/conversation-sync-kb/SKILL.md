---
name: conversation-sync-kb
description: 对话压缩时自动同步摘要到个人知识库，创建 Snapshot 并更新 Daily Digest，确保上下文不丢失。
---

## 对话压缩同步知识库

### 触发时机

**每次对话上下文被压缩（conversation compression / context window reset）时，必须执行此流程。**

这是一条强制规则，不需要用户额外提醒。

### 核心要求

每次触发时必须同时完成两件事：

1. 对当前阶段对话进行结构化总结
2. 通过 MCP 将总结结果同步到知识库

### 流程

1. **整理摘要**：将当前对话中的关键进展、发现、结论、待办整理成结构化 Markdown
2. **创建 Snapshot**：解析 `Projects/<project>/Snapshots/` 目录，调用 `knowledge-base_save_document` 创建新的 `Snapshot Doc`
3. **解析 Daily 目录**：定位 `Daily/<YYYY>/<YYYY-MM>/`
4. **查找当天 Daily Digest**：调用 `knowledge-base_list_documents` 查找 `[daily] YYYY-MM-DD - <project>`
5. **读取旧内容**：如果当天 `Daily Digest` 已存在，先调用 `knowledge-base_get_document` 读取
6. **增量更新 Daily Digest**：
   - 如果当天文档已存在：调用 `knowledge-base_update_document` 做增量更新
   - 如果当天文档不存在：调用 `knowledge-base_save_document` 创建新文档
7. **必要时补长期对象**：如果本次压缩包含重大架构、产品或策略结论，再补 `Decision Doc` 或 `Topic Doc`
8. **确认同步成功**：打印同步结果告知用户

### 文档格式

```markdown
# [snapshot:YYYYMMDD-HHmmss] <project> - Conversation compression handoff

## Objective
（当前阶段在解决什么问题）

## Important Discoveries
（本轮对话里的关键发现、判断、结论）

## Implementation Status
（已完成、进行中、卡住的内容）

## Outstanding Issues
（当前阻塞与风险）

## Next Actions
- [ ] 下一步要做的事情

## Relevant Files / Commands
（本次修改/查看的关键文件路径）
```

### 知识库配置

| 配置项 | 值 |
|--------|-----|
| Snapshot 路径 | `Projects/<project>/Snapshots/` |
| Daily 路径 | `Daily/<YYYY>/<YYYY-MM>/` |
| Snapshot 标题格式 | `[snapshot:YYYYMMDD-HHmmss] <project> - <label>` |
| Daily 标题格式 | `[daily] YYYY-MM-DD - <project>` |
| sourceType | `ai-chat` |

### 保存策略

本技能固定使用 `Snapshot + Daily Digest Sync`。

也就是说：

- 默认创建 `Snapshot Doc`
- 同时维护当天的 `Daily Digest`
- 不负责把长期项目知识硬塞进 daily 文档
- 如本次压缩中包含重大架构/产品决策，可由 `knowledge-manager` 再补 `Decision Doc` 或 `Topic Doc`

### 注意事项

- 摘要要包含足够上下文，让未来的对话能快速恢复工作状态
- 包含具体的文件路径、行号、命令等可操作信息
- 包含未完成的待办事项，方便下次继续
- 避免冗余，突出关键结论和决策
- `Snapshot Doc` 每次压缩都新建，不覆盖旧快照
- `Daily Digest` 在同项目同日期下只维护一份，并按 section 增量更新
- 绝对不要在技能中写死 folderId
- 每次压缩后，不仅要总结，还必须完成 MCP 同步
- 如同步失败，应重试一次，仍失败则明确报告失败原因
