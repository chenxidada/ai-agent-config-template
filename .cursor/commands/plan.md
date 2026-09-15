# /plan — 架构设计专用

当用户使用 `/plan` 时，基于已有的 requirements.md 进行架构设计和 Phase 拆分。停在 Human Gate 2。

## 前置条件
- 当前活跃工作流必须存在
- `current-status.json` 中 HG-1 = `passed`
- `requirements.md` 必须非空

## 流程

### 第一步：代码调研（workflow 模式）

委托 `code-explorer` 调研当前代码库状态，产出：
- `.specdev/specs/<slug>/repo-exploration.md` — 结构化调研报告（10 章节，`ui_relevant: true` 时追加 §11）
- `.specdev/specs/<slug>/repo-exploration-zh.md` — 中文翻译版

> 此时尚未拆 Phase，`current_phase` 为空 → 走 **workflow 模式**，产物落在**工作流级**路径
> （**不是** `phases/<phase>/`）。门禁据此放行 `code-explorer`。
>
> ⚠️ 调研目标是「与本次需求相关的架构面 / 现有约定 / 集成点 / 可复用资产」，
> 不是全仓库综述 —— 目的是让第二步的 `plan-generator` 能写出 `design.md` 的「现状依据」章节。

### 第二步：架构设计

委托 `plan-generator`：
- 读取 requirements.md + repo-exploration.md
- 输出 design.md（含 **现状依据** 章节，每条带 `路径:行号` 证据）+ phase-plan.md（含 Mermaid DAG + JSON 依赖）+ phases/*/spec.md

> 若 `plan-generator` 返回「⏸ STOP & EXPLORE」（设计中发现还需确认的事实）：
> 再次派发 `code-explorer`（workflow 模式）→ **续做** plan-generator。不需要用户决策，不过 HG。

### 第三步：Human Gate 2 — 方案确认 🛑

1. 展示 DAG 图 + Phase 拆分表 + 架构决策
2. 询问：「方案是否合理？确认后使用 `/implement` 开始实施。」
3. 停止，等待确认。
4. 用户确认后更新 `hg2: "passed"` + `current_phase: "phase-1-xxx"`
   > 门禁会在写入 `hg2=passed` 时校验 `design.md` 的「现状依据」章节（L1–L5）

## 后续命令
- `/implement` — 开始实施
- `/brief` — 跳过详细 Phase 拆分，直接实施

## 约束
- 不执行任何实现代码
- 必须基于已确认的 requirements.md
