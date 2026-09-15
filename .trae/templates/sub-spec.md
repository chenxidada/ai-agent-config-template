# Sub-Spec Template

<!--
  此模板用于将单个 Phase 拆分为更细粒度的 sub-spec。
  当前 TRAE pipeline 以 Phase 为最小实施单元，但如有需要更细拆分，
  plan-generator 可用此模板为 Phase 内部创建 sub-spec。
  
  每个 sub-spec 应为：
  - 一次实施周期的大小
  - 独立可验证（有自己的验收标准）
  - 可交付有意义的、可测试的价值
-->

## 目标

<!-- 这个 sub-spec 交付什么 -->

## 为什么现在做这个 sub-spec

<!-- 为什么这个 sub-spec 的顺序在当前 Phase 是最优的 -->

## 范围

<!-- 具体包含什么 -->

## 范围外

<!-- 明确不属于本 sub-spec 的内容 -->

## UI 相关性

<!--
  🔴 必须与 phase-plan.md DAG JSON 中对应 Phase 的 "ui" 字段取值一致。
     不一致时以 DAG JSON 为准（唯一真相源），并回报 plan-generator。

  - **ui**: `true` / `false`
  - **ui: true 时必填**：
    - 本 sub-spec 涉及的页面/路由：
    - ui-spec.md 布局骨架章节引用（如 §3.1）：
    - 需实现的状态（引用 ui-spec.md §6）：
    - 需覆盖的断点（引用 ui-spec.md §7）：
    - 可复用组件来源路径：
    - 设计 token 文件路径（visual-baseline.md §3 冻结表）：
  - **视觉反模式**：本 sub-spec 需特别避免的（引用 design.md §视觉反模式）

  ⚠️ ui: true 时，硬编码任何色值/间距/字号字面量 = must-fix（由 reviewer-visual 判定）。
-->

## 关联模块

<!-- 影响哪些代码模块 -->

## 设计/契约备注

<!-- 关键接口约束、特殊设计注意事项 -->

## 预计文件产出

<!-- 新增 + 修改文件的清单 -->

## 验证方案

### 验证场景

| # | 场景 | 输入/前置条件 | 预期输出/行为 | 类型 |
|---|------|--------------|-------------|------|
<!-- 类型: functional | boundary | error-handling | regression | performance | visual -->

<!--
  ⚠️ ui: true 时，visual 类型场景为 **must**，且必须覆盖：
    - 4 个断点（375 / 768 / 1024 / 1440）各一条
    - ui-spec.md §6 状态矩阵中每个非 default 状态各一条
    - 冻结 token 实测值比对（基准值 vs 实测值）一条
  缺失 visual 场景 → verifier 判 PARTIAL + visual-blocking: true。
-->

### 回归检查

- [ ] ...

### 构建 & Lint

- [ ] 构建通过无错误
- [ ] 无新增 lint 警告
- [ ] （ui: true）无硬编码色值/间距/字号字面量，全部使用 token
- [ ] （ui: true）截图落盘 `screenshots/<phase>/`，含 4 断点 + 状态矩阵

## 完成标准

<!-- 这个 sub-spec 完成的明确判定条件 -->

## 修订记录

<!-- 
  记录实现过程中经 reviewer 批准的偏差。
  由 reviewer 在批准 implementer 偏差后填写。
-->

| # | 日期 | 原计划章节 | 修改为 | 批准人 | 偏差来源 |
|---|------|-----------|--------|--------|---------|
| — | — | — | — | — | — |

### 如何填写修订

1. **implementer** 在 `implementation.md` 的 Deviations 章节中记录偏差，标注影响的 sub-spec 章节编号
2. **reviewer** 审查偏差：如批准，在本表增加一行

## 变更日志

- 变更原因:
- 变更内容:
- 影响:
