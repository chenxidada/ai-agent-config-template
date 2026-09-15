# Phase Requirements Template

<!--
  此模板由 TRAE Agent 在需要从整体需求中提取 per-phase 需求时使用。
  当前 pipeline 中 requirement-analyst → plan-generator 直接衔接，
  但在需要更精细化的需求追踪时（如 Phase 间有严格接口契约），
  可用此模板提取 Phase 专属需求。
  
  下游消费者：plan-generator（设计范围）、implementer（硬接口定义）、reviewer/validator（验收标准）。
  
  规则：
  - 每条需求必须追溯到整体 requirements.md 的源章节+行号
  - 不发明新需求 —— 只提取和细化已有的
  - 定量约束不得被概括为描述性文本 —— 保留精确值
-->

## Phase 标识

<!-- 
  Phase ID 和名称，匹配 phase-plan.md。
  示例：
  - Phase ID: phase-1-core-crud
  - Phase Name: Core CRUD Operations
-->

## Phase 目标

<!-- 一句话：完成这个 Phase 能达成什么 -->

## Phase 问题陈述

<!-- 这个 Phase 解决什么问题？当前状态是什么？谁被阻塞？ -->

## Phase 目标终态

<!-- 这个 Phase 完成后成功长什么样？之前不可能的什么现在可能了？ -->

## 纳入的需求

<!-- 
  从 requirements.md 中提取属于本 Phase 的具体需求。
  按功能区域分组。引用原始编号。
-->

## 验收标准

<!-- 
  只提取本 Phase 必须满足的验收标准。
  使用 checklist 格式。
  
  示例：
  - [ ] AC-1: 用户可以创建、重命名、删除文件夹
  - [ ] AC-3: 用户可以创建文档并用 Markdown 编辑
-->

## UI 相关性

<!--
  🔴 必须与 phase-plan.md DAG JSON 中本 Phase 的 "ui" 字段一致；不一致以 DAG JSON 为准。
     此字段被 pipeline-gate.sh 的 read_phase_ui() 读取，用于启用：
     ui-spec.md / visual-baseline.md 存在性门禁、原型确认门禁、reviewer-visual 派发、视觉验证强制化。

  - **ui**: `true` / `false`
  - **ui: true 时必填**：
    - 本 Phase 页面/路由清单：
    - ui-spec.md 布局骨架引用：§
    - 状态矩阵引用：ui-spec.md §6
    - 断点覆盖引用：ui-spec.md §7
    - 冻结 token 来源：visual-baseline.md §3

  ⚠️ ui: true 时，本 Phase 的视觉验证项为 must —— verifier 缺视觉证据即判
     PARTIAL + visual-blocking: true，不可静默放行。
-->

## 排除项

<!-- requirements.md 中明确不属于本 Phase 的需求。标注归属 Phase。-->

## 继承的约束

<!-- 从 requirements.md 中继承的、影响本 Phase 的约束 -->

## Phase 专属风险/假设

| # | 风险 | 严重性 | 影响 | 缓解 |
|---|------|:------:|------|------|

## Phase 相关待解决问题

<!-- 从 requirements.md 中提取与本 Phase 相关的开放问题 -->

## 源文档追溯

<!-- 
  映射本文档中每条需求到其源文档。
  
  | 本文档 | 源文档 | 章节/行号 |
  |--------|--------|-----------|
  | §验收标准 AC-1 to AC-5 | requirements.md | §Acceptance Criteria |
-->

## 用户已确认的决策

<!-- 携带 requirements.md 中的用户已确认决策。Agent 不得修改。-->

## 依赖

<!-- 本 Phase 启动前必须就位的事项 -->
