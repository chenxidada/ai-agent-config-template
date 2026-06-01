# Dispatch Prompt Template

Orchestrator uses this template when dispatching each agent. Fill in the fields, do NOT write free-text task descriptions.

---

## repo-explorer

```markdown
## What you need to do（从上游文档引用，不作概括）
探索代码库：<一句话 from requirement>

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `specs/tech-debt-registry.md` | 技术债注册表 | §活跃债务 — 交叉验证已知桩 |

## Phase context
关键词：<列表>
code2prompt 可用：yes / no

## Output
→ `<path>`
```

---

## requirement-analyst

```markdown
## What you need to do（从上游文档引用，不作概括）
定义需求：<一句话 from user requirement>

## Mode
<create / extract / append>

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `specs/exploration/repo-exploration.md` | 仓库探索结果 | 全文 |

## Output
→ `specs/requirements/requirements.md`
```

---

## program-planner

```markdown
## What you need to do（从上游文档引用，不作概括）
拆分 Phase：<一句话 from requirements>

## Mode
<first-time / append>

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `specs/requirements/requirements.md` | 需求文档 | 全文 |
| `specs/exploration/repo-exploration.md` | 仓库探索 | 全文 |

## Output
→ `specs/master-spec.md`
→ `specs/phases/<id>/requirements.md`
```

---

## task-planner

```markdown
## What you need to do（从上游文档引用，不作概括）
为 Phase `<id>` 拆解 Sub-Spec

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `specs/master-spec.md` | 主控文档 | §本 Phase 的模块合同 |
| `specs/phases/<id>/requirements.md` | Phase 需求 | 全文 |
| `specs/tech-debt-registry.md` | 技术债注册表 | §活跃债务 — 目标Phase=本Phase |

## Inherited obligations（直接粘贴查询结果）
| ID | 描述 | 目标Phase | 阻塞 |
|----|------|:--------:|:---:|
| `<直接粘贴>` |

## Output
→ `specs/phases/<id>/phase-spec.md`
```

---

## solution-architect

```markdown
## What you need to do（从上游文档引用，不作概括）
设计 Sub-Spec `<id>`：<一句话 from phase-spec>

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `specs/phases/<id>/phase-spec.md` | Phase 计划 | §本 Sub-Spec 的定义 |
| `specs/phases/<id>/requirements.md` | Phase 需求 | 全文 |
| `specs/tech-debt-registry.md` | 技术债注册表 | 依赖的接口是否已知桩？ |

## Output
→ `<sub-spec.md>`
→ `<solution-design.md>`
```

---

## implementer

```markdown
## What you need to do（从上游文档引用，不作概括）
实现 `<sub-spec-id>`：<引用 sub-spec.md §Completion Criteria 的一句话>

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `<sub-spec.md>` | 实现范围 | §Completion Criteria、§Validation Plan |
| `<solution-design.md>` | 技术方案 | §Architecture、§File Output Plan |
| `specs/tech-debt-registry.md` | 技术债注册表 | 你依赖的接口是否已知桩？ |

## Upstream context（直接粘贴，不转述）
<如果是 loop-back，粘贴上一轮 reviewer/validator 的问题原文>
<直接粘贴 implementer 需要知道的 Deviations/Known Gaps>

## Constraints
可以改：<文件 or 目录>
不能改：<文件 or 目录>

## Git
分支：`impl-<sub-spec-id>`
loop-back：yes / no
方向性错误 → 回滚分支 / 局部修复 → 当前分支继续

## Output
→ `<implementation-summary.md>`
```

---

## reviewer

```markdown
## What you need to do（从上游文档引用，不作概括）
审查 `<sub-spec-id>` 的实现

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `<sub-spec.md>` | 审查基准 | §Acceptance Criteria、§Amendments |
| `<solution-design.md>` | 设计基准 | §Architecture |
| `<implementation-summary.md>` | 实现总结 | §Deviations、§Known Gaps、§Placeholders/Stubs |
| `specs/tech-debt-registry.md` | 技术债注册表 | 已知桩（不重复发现） |

## Upstream context（直接粘贴）
implementer 的 Deviations：
```
<直接粘贴原文>
```
implementer 的 Known Gaps：
```
<直接粘贴原文>
```
<如果是 re-review，粘贴上一轮 must-fix 项原文>

## Constraints
不修改实现代码，只审查

## Output
→ `<review-report.md>`
```

---

## validator

```markdown
## What you need to do（从上游文档引用，不作概括）
验证 `<sub-spec-id>` 的实现

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `<sub-spec.md>` | 验证基准 | §Validation Plan、§Amendments |
| `<review-report.md>` | 审查发现 | §Additional Test Scenarios、§🔴must-fix |
| `<implementation-summary.md>` | 实现详情 | §Known Gaps（不需要验证）、§Placeholders/Stubs |
| `specs/tech-debt-registry.md` | 技术债注册表 | 已知桩（跳过验证） |

## Upstream context（直接粘贴）
Validation Plan：
```
<直接粘贴原文>
```
reviewer 的 Additional Test Scenarios：
```
<直接粘贴原文>
```
implementer 的 Known Gaps（不需要验证）：
```
<直接粘贴原文>
```
<如果是 re-validation，粘贴上一轮 fail 原因原文>

## Requirements
你必须设计至少一个自己独立的验证场景，不依赖 implementer 的测试

## Constraints
不修改实现代码，只验证 + 可写临时测试脚本

## Output
→ `<validation-report.md>`
```

---

## code-analyst

```markdown
## What you need to do（从上游文档引用，不作概括）
<analysis / review / diagnosis>：<一句话>

## Mode
<analysis / review / diagnosis>

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `specs/tech-debt-registry.md` | 技术债注册表 | §活跃债务 |
| `<failure report>` | 失败报告（诊断模式） | 全文 |

## Output
→ `<path>`
```

---

## knowledge-manager

```markdown
## What you need to do（从上游文档引用，不作概括）
同步知识库：<类型>

## Sync
类型：<topic / decision / task>
project：`<from project-config.md>`

## Must-read files
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `<待同步的文件>` | 同步内容 | 全文 |

## Output
→ KB 同步确认
```
