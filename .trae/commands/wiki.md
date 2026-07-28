---
name: wiki
description: 维护项目 Wiki 深度文档。独立调用时全量扫描代码，以四阶段流水线生成按主题域组织的 docs/wiki/；也可在 Feature 完成后由 pipeline 自动触发（仅处理变更模块）。
---

# /wiki 命令

## 用法

```
/wiki              — 全量扫描代码，走四阶段流水线生成或更新 docs/wiki/ 全部主题域
/wiki update       — 同上（别名）
/wiki init         — 首次初始化，从零建立全部主题域文档
/wiki changelog    — 仅更新 changelog.md（快速模式）
```

## 四阶段流水线概览

无论哪种触发方式，wiki agent 都以四阶段流水线工作，阶段间以显式中间产物文件解耦（写入 `.wiki-work/`），**严格顺序、禁止跳阶**：

```
阶段 1 代码分析   → .wiki-work/module-manifest.json      （模块清单 + 复杂度判定）
阶段 2 主题规划   → .wiki-work/topic-plan.json           （按主题域组织的目录规划）
                  + .wiki-work/code-snippets.json        （先索引后引用的源码片段索引）
阶段 3 深度生成   → docs/wiki/<主题域>/**.md              （逐页生成，引用索引条目）
阶段 4 质量门禁   → .wiki-work/quality-report.json        （度量深度 + 更新 .wiki-status.json）
```

目录按**主题域**组织（完全替换旧的 L1/L2/L3/L4），每个主题域含一个同名概览页（如 `docs/wiki/安全机制/安全机制.md`）。

## 触发流程

### 独立调用（/wiki 或 /wiki update）

```
用户输入 /wiki
  │
  ├─ 1. 委托 wiki agent（模式 = standalone）
  │     - 传入：项目根路径、现有 wiki 路径、模式 standalone
  │
  ├─ 2. wiki agent 执行四阶段流水线
  │     - 阶段 1：全量扫描项目代码结构 → module-manifest.json
  │     - 阶段 2：规划主题域目录 + 建源码片段索引 → topic-plan.json + code-snippets.json
  │     - 阶段 3：逐主题域逐页深度生成 → docs/wiki/**
  │     - 阶段 4：质量门禁度量 → quality-report.json + 更新 .wiki-status.json
  │
  └─ 3. 向用户报告更新结果
        - 生成/更新了哪些主题域
        - 新增了哪些子主题页
        - 质量报告摘要（pass / supplement-needed / limited-content）
```

### Pipeline 集成（Feature 完成后自动触发）

```
最后一个 Phase 的 HG-3 通过
  │
  ├─ commit + merge + 删分支（现有流程）
  ├─ KB 同步（现有流程）
  │
  └─ 委托 wiki agent（模式 = pipeline）
        - 传入：spec slug、所有 Phase 的 implementation.md 路径
        - wiki agent 走四阶段流水线，但阶段 1 仅纳入 implementation.md 变更涉及的模块
        - 仅重写受影响主题域页面 + 追加 changelog + 更新 .wiki-status.json
```

## 调度者行为

### 独立调用时

1. 直接委托 `wiki` agent，模式 = `standalone`
2. wiki agent 完成四阶段后，向用户报告更新概要 + 质量报告摘要
3. **不涉及 Human Gate** — wiki 更新不阻塞任何流程

### Pipeline 触发时

1. 在最后 Phase HG-3 流程的末尾，委托 `wiki` agent，模式 = `pipeline`
2. 传入当前 feature slug
3. wiki agent 完成后，调度者在 HG-3 报告中附带一行："Wiki 已更新"
4. **非阻塞** — wiki 更新失败不阻塞 pipeline 推进

## 委托 wiki agent 的 dispatch 格式

### 独立模式

```
请更新项目 Wiki 文档。

模式：standalone
项目根目录：<project_root>
Wiki 目录：<project_root>/docs/wiki/
中间产物目录：<project_root>/.wiki-work/

任务（严格四阶段，禁止跳阶）：
1. 阶段 1 代码分析：全量扫描项目代码，识别模块结构与复杂度，产出 .wiki-work/module-manifest.json
2. 阶段 2 主题规划：按主题域组织目录规划（每个主题域一个同名概览页），并先建源码片段索引，
   产出 .wiki-work/topic-plan.json + .wiki-work/code-snippets.json
3. 阶段 3 深度生成：逐主题域逐页生成 docs/wiki/**，行号标注必须引用 code-snippets.json 中的条目
4. 阶段 4 质量门禁：度量各页深度信号，产出 .wiki-work/quality-report.json，更新 .wiki-status.json（v2）

要求：
- 目录按主题域组织，完全替换旧的 L1/L2/L3/L4 结构
- 所有图表使用 Mermaid 内联，不使用外部图片链接
- 每段内容附精确源码追溯（对应 code-snippets.json 索引条目）
- 中文书写，技术术语保持英文
```

### Pipeline 模式

```
请根据 Feature 开发产出更新项目 Wiki。

模式：pipeline
Feature slug：<slug>
Spec 目录：.specdev/specs/<slug>/
Wiki 目录：<project_root>/docs/wiki/
中间产物目录：<project_root>/.wiki-work/

输入文件：
- .specdev/specs/<slug>/design.md
- .specdev/specs/<slug>/phases/*/implementation.md
- .specdev/specs/<slug>/tech-debt-registry.md

任务（严格四阶段，禁止跳阶）：
1. 阶段 1 代码分析：读取以上文件确定变更影响范围，module-manifest.json 仅纳入受影响模块
2. 阶段 2 主题规划：为受影响模块规划/更新主题域目录，建源码片段索引
3. 阶段 3 深度生成：仅重写受影响主题域的页面，其余主题域保持不变
4. 阶段 4 质量门禁：度量深度，产出 quality-report.json，追加 changelog.md，更新 .wiki-status.json（v2）

要求：
- 只更新受影响的主题域，不重写未变更内容
- changelog 必须包含：日期、slug、概要、影响模块、遗留债务（来自 tech-debt-registry）
- 所有新增图表使用 Mermaid 内联
- 每段内容附精确源码追溯（对应 code-snippets.json 索引条目）
```
