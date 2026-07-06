---
description: 独立需求分析（EARS格式AC）
argument-hint: <需求描述>
---

# /specify — 需求分析专用

当用户使用 `/specify <描述>` 时，仅执行需求分析阶段，停在 Human Gate 1。适合只想讨论需求、不急于实施的场景。

## 流程

### 第一步：初始化

1. 生成 slug，创建目录，初始化 current-status.json（`current_stage: requirement-analysis`）
2. 复制 constitution + registry 模板

### 第二步：需求分析

委托 `requirement-analyst` 按 EARS 5 种模式书写验收标准。

### 第三步：Human Gate 1 — 需求确认 🛑

1. 展示需求摘要
2. 询问：「需求是否完整？是否需要补充？确认后可以继续 `/plan` 进行架构设计，或 `/implement` 开始实施。」
3. 停止，等待确认。
4. 用户确认后更新 `hg1: "passed"` → 提示下一步可用命令

## 后续命令
- `/plan` — 继续架构设计
- `/brief` — 转为快速实施（跳过详细设计）
- `/feature` — 继续完整流程

## 约束
- 不执行任何实现代码
- 不进入 HG-2/3
