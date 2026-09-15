# 派遣提示模板

<!--
  TRAE Agent 使用 Task 工具派遣每个子 agent 时使用。
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
| `.specdev/specs/{slug}/ui-spec.md` | UI 规格（仅 ui: true） | 页面/组件/状态矩阵 — 定位现有组件与主题配置 |

## 探索范围
关键词：{逗号分隔的关键词列表}
<!-- ui: true 时追加：UI 组件库、设计系统、Tailwind config、CSS 变量/主题文件、可复用组件变体 -->

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
→ `.specdev/specs/{slug}/ui-spec.md`（**仅当 UI 相关性判定为 true**，按 `.trae/templates/ui-spec-output.md`）
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
| `.specdev/specs/{slug}/ui-spec.md` | UI 规格（仅 ui: true） | 布局骨架/状态矩阵/断点行为 |
| `.specdev/specs/{slug}/tech-debt-registry.md` | 技术债注册表 | 依赖的接口是否已知桩？ |

## UI 工作流（ui-spec.md 存在时强制执行）
1. 执行 `python3 .trae/skills/ui-ux-pro-max/scripts/search.py "<产品> <行业> <关键词>" --design-system --persist -p "{slug}"`
2. 落盘 `design-system/{slug}/MASTER.md` + `pages/<page>.md`
3. 产出 `.specdev/specs/{slug}/visual-baseline.md`（2-3 套候选风格 + 推荐项 + 冻结声明）
4. DAG JSON 中为每个 Phase 显式标注 `"ui": true/false`
5. design.md 必须含「UI / Design System」章节（token 引用 / 路由表 / 组件清单 / 状态覆盖 / 断点策略 / 反模式）

## Output
→ `.specdev/specs/{slug}/design.md`
→ `.specdev/specs/{slug}/phase-plan.md`
→ `.specdev/specs/{slug}/phases/{phase-id}/spec.md`（每个 Phase 各一份）
→ `.specdev/specs/{slug}/visual-baseline.md`（仅 UI 工作流）
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
| `.specdev/specs/{slug}/ui-spec.md` | UI 规格（仅 ui: true） | 布局骨架/状态矩阵/断点行为 |
| `.specdev/specs/{slug}/visual-baseline.md` | 视觉基准（仅 ui: true） | §3 冻结 token — **禁止使用表外值** |

## 上游上下文（直接粘贴，不转述）
{如果是 loop-back，粘贴上一轮 reviewer 的 must-fix 项原文}
{直接粘贴 implementer 需要知道的 Deviations/Known Gaps}

## 约束
应该改的文件：{文件或目录}
不能改的文件：{文件或目录}

## UI Phase 协议（ui: true 时）
→ 第一轮**只出静态原型** + 截图，写 `## Prototype（待确认）` 章节后**停止**，等用户确认。
→ 用户确认后才接入真实数据/逻辑（第二轮）。
→ 禁止硬编码色值/间距/字号字面量，一律使用 visual-baseline.md §3 的 token。

## Git
分支：`impl-{phase-id}`
loop-back：yes / no
→ 方向性错误：回滚分支重开 / 具体修复：当前分支继续

## Output
→ `.specdev/specs/{slug}/phases/{phase}/implementation.md`
```

---

## reviewer-correctness / reviewer-design / reviewer-connectivity / reviewer-visual

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
| `.specdev/specs/{slug}/ui-spec.md` | UI 规格（仅 reviewer-visual） | 布局骨架/状态矩阵/断点行为 |
| `.specdev/specs/{slug}/visual-baseline.md` | 视觉基准（仅 reviewer-visual） | §3 冻结 token — 硬编码检测的对照表 |
| `design-system/{slug}/MASTER.md` | 设计系统（仅 reviewer-visual） | 反模式清单 / token 定义 |

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
| `.specdev/specs/{slug}/phases/{phase}/review-visual.md` | 视觉审查（仅 ui: true） | 硬编码 token / 状态缺失 / 反模式命中 |
| `.specdev/specs/{slug}/phases/{phase}/review.md` | 合并审查 | 统一判决 |
| `.specdev/specs/{slug}/phases/{phase}/implementation.md` | 实现详情 | Known Gaps（不验证） |
| `.specdev/specs/{slug}/tech-debt-registry.md` | 技术债注册表 | 已知桩（跳过验证） |
| `.specdev/specs/{slug}/ui-spec.md` | UI 规格（仅 ui: true） | 状态矩阵 / 断点行为 — 派生验证场景 |
| `.specdev/specs/{slug}/visual-baseline.md` | 视觉基准（仅 ui: true） | §3 冻结 token — 基准对比表的 ground truth |

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

## UI Phase 要求（ui: true 时）
→ Playwright MCP 为**强制**手段（不可用则 bash + 项目内 Playwright 兜底）。
→ 必须落盘：4 断点截图（375/768/1024/1440）+ 状态矩阵逐项截图 → `screenshots/{phase}/`
→ 必须产出基准对比表（维度 / 基准值 / 实测值 / 判定）
→ 必须检查 console 零 error + network 无 4xx/5xx 资源
→ 视觉证据缺失 → 判决 PARTIAL 并标 `visual-blocking: true`（不可静默放行）

## 约束
不修改实现代码，只验证 + 可写临时测试脚本

## Output
→ `.specdev/specs/{slug}/phases/{phase}/verification.md`
```
