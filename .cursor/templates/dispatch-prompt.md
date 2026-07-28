# 派遣提示模板

<!--
  Cursor Agent 使用 Task 工具派遣每个子 agent 时使用。
  填写字段，不要用自由文本描述任务。
-->

---

## code-explorer

```markdown
## 任务
探索代码库：{一句话描述调研目标}

## 必须读取
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `.specdev/specs/{slug}/tech-debt-registry.md` | 技术债注册表 | 交叉验证已知桩 |
| `.specdev/specs/{slug}/phases/{phase}/spec.md` | Phase 规格 | 了解本 Phase 目标 |

## 探索范围
关键词：{逗号分隔的关键词列表}

## Output
→ `.specdev/specs/{slug}/phases/{phase}/repo-exploration.md`
```

---

## requirement-analyst

```markdown
## 任务
定义需求：{一句用户需求}

## 必须读取
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `.specdev/specs/{slug}/constitution.md` | 项目宪法 | 全文 — 项目级约束 |

## Output
→ `.specdev/specs/{slug}/requirements.md`
```

---

## plan-generator

```markdown
## 任务
设计架构 + 拆分 Phase：{一句话 from requirements}

## 必须读取
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `.specdev/specs/{slug}/requirements.md` | 需求文档 | 全文 |
| `.specdev/specs/{slug}/tech-debt-registry.md` | 技术债注册表 | 依赖的接口是否已知桩？ |

## Output
→ `.specdev/specs/{slug}/design.md`
→ `.specdev/specs/{slug}/phase-plan.md`
→ `.specdev/specs/{slug}/phases/{phase-id}/spec.md`（每个 Phase 各一份）
```

---

## implementer

```markdown
## 任务
实现 Phase {phase-id}：{引用 spec.md 验收标准的一句话}

## 必须读取
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `.specdev/specs/{slug}/phases/{phase}/spec.md` | 实现范围 | 验收标准 |
| `.specdev/specs/{slug}/design.md` | 架构约束 | 与本 Phase 相关的决策 |
| `.specdev/specs/{slug}/phases/{phase}/repo-exploration.md` | 代码探索 | 代码库上下文 |
| `.specdev/specs/{slug}/tech-debt-registry.md` | 技术债注册表 | 检查目标 Phase 有哪些债 |

## 上游上下文（直接粘贴，不转述）
{如果是 loop-back，粘贴上一轮 reviewer 的 must-fix 项原文}
{直接粘贴 implementer 需要知道的 Deviations/Known Gaps}

## 约束
应该改的文件：{文件或目录}
不能改的文件：{文件或目录}

## Git
分支：`impl-{phase-id}`
loop-back：yes / no
→ 方向性错误：回滚分支重开 / 具体修复：当前分支继续

## Output
→ `.specdev/specs/{slug}/phases/{phase}/implementation.md`
```

---

## reviewer-correctness / reviewer-design / reviewer-connectivity

```markdown
## 任务
审查 Phase {phase-id}：{视角}

## 必须读取
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `.specdev/specs/{slug}/phases/{phase}/spec.md` | 审查基准 | 验收标准 |
| `.specdev/specs/{slug}/phases/{phase}/implementation.md` | 实现总结 | 偏差和变更清单 |
| `.specdev/specs/{slug}/phases/{phase}/repo-exploration.md` | 代码探索 | 代码库上下文 |
| `.specdev/specs/{slug}/design.md` | 设计文档 | 架构决策 |
| `.specdev/specs/{slug}/tech-debt-registry.md` | 技术债注册表 | 已知桩（不重复发现） |

## 上游上下文（直接粘贴）
implementer 的 Deviations：
```
{直接粘贴原文}
```
implementer 的 Known Gaps：
```
{直接粘贴原文}
```
{如果是 re-review，粘贴上一轮 must-fix 项原文}

## 约束
不修改实现代码，只审查 + 可写 spec 文件

## Output
→ `.specdev/specs/{slug}/phases/{phase}/review-{perspective}.md`
```

---

## verifier

```markdown
## 任务
验证 Phase {phase-id}：{一句话}

## 必须读取
| 文件 | 这是什么 | 重点读 |
|------|---------|-------|
| `.specdev/specs/{slug}/phases/{phase}/spec.md` | 验证基准 | 验收标准 |
| `.specdev/specs/{slug}/phases/{phase}/review-correctness.md` | 正确性审查 | 桩检测、must-fix |
| `.specdev/specs/{slug}/phases/{phase}/review-design.md` | 设计审查 | 架构违反 |
| `.specdev/specs/{slug}/phases/{phase}/review-connectivity.md` | 连通性审查 | 数据路径断裂 |
| `.specdev/specs/{slug}/phases/{phase}/review.md` | 合并审查 | 统一判决 |
| `.specdev/specs/{slug}/phases/{phase}/implementation.md` | 实现详情 | Known Gaps（不验证） |
| `.specdev/specs/{slug}/tech-debt-registry.md` | 技术债注册表 | 已知桩（跳过验证） |

## 上游上下文（直接粘贴）
验收标准：
```
{直接粘贴 spec.md 的验收标准原文}
```
reviewer 的建议验证命令：
```
{直接粘贴原文}
```
implementer 的 Known Gaps（不需要验证）：
```
{直接粘贴原文}
```
{如果是 re-validation，粘贴上一轮 fail 原因原文}

## 要求
你必须设计至少一个自己独立的验证场景，不依赖 implementer 的测试。验证脚本必须落盘到 test-scripts/。

## 约束
不修改实现代码，只验证 + 可写临时测试脚本

## Output
→ `.specdev/specs/{slug}/phases/{phase}/verification.md`
```
