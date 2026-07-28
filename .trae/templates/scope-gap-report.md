# Phase {N} Scope Gap Report

> **Phase**: `{phase-id}`
> **生成时间**: {ISO timestamp}
> **工作流**: `{slug}`

<!--
  Phase 退出交付物：「承诺了什么 vs 实际交付了什么」
  由 TRAE Agent 在 HG-3（Phase 完成确认）时生成。
  
  用途：
  - 记录 Phase 完成度（Capability Claim 逐条对照）
  - 分类推迟/未完成项（为 Phase Entry Gate 提供债务继承清单）
  - 汇总 Should-Fix 项
  - 生成 Phase Exit Verdict
-->

## 一、验收标准完成度

| # | AC | 描述 | 状态 | 证据 | 备注 |
|---|:--:|------|:--:|------|------|
| 1 | AC-1 | {description} | ✅ 完成 | {verification.md 中的验证证据} | |
| 2 | AC-2 | {description} | ⚠️ 部分 | {为什么是部分} | |
| 3 | AC-3 | {description} | ❌ 未完成 | N/A | 推迟到 Phase {Y} |

**汇总**: {N}/{Total} 完成, {N} 部分, {N} 未完成

## 二、推迟/未完成项分类

| # | 项目 | 类型 | 目标 Phase | 阻塞下游？ | 关联 AC |
|---|------|:----:|:----------:|:--------:|:------:|
| 1 | {item} | 推迟 | Phase {Y} | 是 (AC-{X} 依赖) | AC-{X} |
| 2 | {item} | 环境降级 | Phase {Z} | 否 | — |
| 3 | {item} | 遗漏 | TBD | TBD | — |

类型定义：
- **推迟**：有意推迟，已规划到特定 Phase
- **环境降级**：环境/硬件限制，需外部条件满足后才能完成
- **遗漏**：审查/验证中发现的非预期缺失

## 三、Should-Fix 汇总

| # | 来源 | 问题 | 严重性 | 修复计划 | 状态 |
|---|------|------|:------:|---------|:----:|
| 1 | review.md §{section} | {description} | should-fix | Phase {Y} | 待处理 |

**汇总**: {N} 个 should-fix 项, {N} 个已在 Phase 内解决, {N} 个携带至后续 Phase

## 四、Design Document 更新检查清单

| # | Design Doc 章节 | 更新内容 | 状态 |
|---|----------------|---------|:----:|
| 1 | §{X.Y} {section name} | {变更内容} | ✅ 已完成 |
| 2 | §{X.Y} {section name} | {待更新内容} | ❌ 未完成 |

## 五、Phase Exit Verdict

- [ ] 所有验收标准已验证完成或明确标记为部分/推迟
- [ ] 推迟项已注册到 `tech-debt-registry.md`，标注目标 Phase
- [ ] Should-Fix 项已追踪，标注修复计划
- [ ] Design Document 更新已执行或已追踪
- [ ] 无未知影响的「遗漏」项
- [ ] Reviewer/Verifier 判决均为 PASS 或已处理 MUST-FIX

**Phase Exit Decision**: {PASS / PASS_WITH_CONDITIONS / BLOCKED}

如有条件通过（PASS_WITH_CONDITIONS）：
- {条件 1}
- {条件 2}
