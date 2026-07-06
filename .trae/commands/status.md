---
description: 查看当前工作流进度和技术债快照
---

# /status — 查看工作流进度

当用户使用 `/status` 时，快速展示当前活跃工作流的状态。

## 流程

### 第一步：定位活跃工作流

读取 `.specdev/active-workflow` → 获取当前 slug。

如果没有活跃工作流 → 列出 `.specdev/specs/workflows.json` 中所有已完成/暂停的工作流，询问用户要恢复哪个。

### 第二步：读取状态

读取 `.specdev/specs/<slug>/current-status.json` + `tech-debt-registry.md`

### 第三步：展示进度报告

用以下格式向用户呈现：

```markdown
## 📊 工作流进度：`<slug>`

**描述**: <description>
**当前阶段**: <current_stage>
**当前 Phase**: <current_phase>（如适用）

### Human Gate 状态
| HG-1 需求确认 | HG-2 方案确认 | HG-3 Phase 验收 |
|:---:|:---:|:---:|
| <hg1> | <hg2> | <hg3> |

### Phase 进度
| Phase | 实现 | 审查 | 验证 |
|-------|:--:|:--:|:--:|
| phase-1-xxx | completed | completed | completed |
| phase-2-yyy | in_progress | pending | pending |

### 技术债快照
- 活跃债务: N 条（🔴阻塞 M 条  🟡非阻塞 K 条）
- 本周应处理: X 条（目标Phase = 当前Phase）
- 回路计数: <loop_count> / 2

### 下一步
→ <基于 current_status 推断的下一步操作>
```

### 第四步：给出建议

根据当前状态给出具体建议：

| 状态 | 建议 |
|------|------|
| HG-1=pending | → 等待用户确认需求后，更新 hg1=passed，调用 @plan-generator |
| HG-2=pending | → 等待用户确认方案后，更新 hg2=passed，调用 @implementer |
| implementer=pending | → 调用 @implementer 实现当前 Phase |
| reviewer=pending | → 调用 @reviewer 审查 |
| verifier=pending | → 调用 @verifier 验证 |
| HG-3=pending | → 展示验证结果，等待用户确认 |
| loop_count=2 | → ⚠️ 回路达到上限，需用户介入决策 |
| 全部完成 | → 🎉 所有 Phase 完成，确认收尾 |
