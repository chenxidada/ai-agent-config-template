# Tech Debt Registry

Single source of truth for all outstanding technical debt across phases. All agents read and write this file.

**Rules**: Register new stubs/placeholders/gaps on creation. Move resolved items to §已解决 on resolution. Check before depending on any interface.

---

## 活跃债务

*（当前无活跃债务。GAP-001 已解决，见 §已解决；ENF 模板格式见 §模板参考。）*

---

## 模板参考

> 以下为格式模板，非真实违规/债务。实际注册时请参考这些格式。

### Enforcement Violation (ENF) 格式模板

```markdown
### [ENF-<seq>] Enforcement Violation — <date>

| Field | Value |
|-------|-------|
| **ID** | ENF-<seq> |
| **type** | enforcement-violation |
| **target** | <file or command> |
| **violation** | <what the Orchestrator did that was blocked or detected> |
| **date** | YYYY-MM-DD |
| **session** | <sessionID> |
| **resolution** | <how it was resolved — re-dispatched, user override, rule adjustment> |
| **severity** | 🟢 LOW / 🟡 MEDIUM / 🔴 HIGH |
| **module:** | orchestrator |
```

### Stub/Gap/Placeholder 格式模板

| Field | Description |
|-------|-------------|
| **ID** | `STUB-<seq>` or `GAP-<seq>` or `ENF-<seq>` |
| **type** | `stub` / `placeholder` / `known-gap` / `enforcement-violation` |
| **location** | `file:function:line` |
| **description** | What is missing or incomplete |
| **depends_on** | Upstream stubs or phases that must complete first |
| **target_phase** | Phase where this will be resolved |
| **severity** | 🟢 LOW / 🟡 MEDIUM / 🔴 HIGH |
| **blocking** | 🔴 / 🟡 / 🟢 |
| **module:** | `<module-name>` |

---

## 已解决

### [GAP-001] HG1/HG2 合规检查清单 — 已追加到 orchestrator.md

| Field | Value |
|-------|-------|
| **ID** | GAP-001 |
| **type** | known-gap |
| **location** | `.opencode/agents/orchestrator.md:§Human Gates` (lines 383-413) |
| **description** | HG1 compliance checklist (Pipeline Compliance Check table) and HG2 compliance report (Stage Execution Summary + Enforcement Violation Log + Compliance Verdict) inserted into Human Gate presentation format. |
| **resolved_date** | 2026-06-16 |
| **resolved_in** | `impl-phase3-gap001-fix` branch |
| **resolution** | Inserted HG1 compliance checklist after line 381 (end of Human Gate format block) and HG2 compliance report after HG1 block. Existing content preserved, new content appended at end of §Human Gates section. |

---

## 维护规则

1. **注册**: 创建桩/占位符时立即注册到 §活跃债务
2. **检查**: 依赖任何接口前先搜索此文件
3. **解决**: 桩被填充后移至 §已解决，记录解决日期
4. **同步**: Phase Closure 时同步 scope-gap-report 中的延期项
5. **去重**: 注册前搜索已有条目，避免重复
