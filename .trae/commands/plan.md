---
description: 独立架构设计（输出DAG Phase拆分）
argument-hint: <可选：设计目标>
---

# /plan — 架构设计专用

当用户使用 `/plan` 时，基于已有的 requirements.md 进行架构设计和 Phase 拆分。停在 Human Gate 2。

## 前置条件
- 当前活跃工作流必须存在
- `current-status.json` 中 HG-1 = `passed`
- `requirements.md` 必须非空

## 流程

### 第一步：代码调研

委托 `code-explorer` 调研当前代码库状态，产出：
- `.specdev/specs/<slug>/phases/<phase>/repo-exploration.md` — 结构化调研报告

### 第二步：架构设计

委托 `plan-generator`：
- 读取 requirements.md + repo-exploration.md
- 输出 design.md + phase-plan.md（含 Mermaid DAG + JSON 依赖）+ phases/*/spec.md

### 第三步：Human Gate 2 — 方案确认 🛑

1. 展示 DAG 图 + Phase 拆分表 + 架构决策
2. 询问：「方案是否合理？确认后使用 `/implement` 开始实施。」
3. 停止，等待确认。
4. 用户确认后更新 `hg2: "passed"` + `current_phase: "phase-1-xxx"`

## 后续命令
- `/implement` — 开始实施
- `/brief` — 跳过详细 Phase 拆分，直接实施

## 约束
- 不执行任何实现代码
- 必须基于已确认的 requirements.md
