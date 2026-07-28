---
description: 快速轻量开发（< 3 文件改动，单Phase + 单视角）
argument-hint: <任务描述>
---

# /brief — 快速轻量开发

当用户使用 `/brief <描述>` 时，启动简化的快速开发流程。适用于简单、边界清晰的功能。

## 与 /feature 的区别

| | /brief | /feature |
|------|------|------|
| **适用** | 简单功能（改动 < 3 个文件、单一模块） | 复杂功能（多模块、多 Phase） |
| **Phase 拆分** | 无，单个 Phase | 2-5 个 Phase + DAG |
| **code-explorer** | 轻量，口头输出 | 完整，写入文件 |
| **review** | 单 reviewer | 并行三视角 reviewer |
| **Human Gate** | HG-1 + HG-2 + HG-3（简易） | 完整 HG-1/2/3 |
| **时间** | ~10-15min | ~30-60min |

## 流程

### 第一步：初始化

1. 生成 slug，创建 `.specdev/specs/<slug>/`，初始化 current-status.json（`current_stage: brief-analysis`）
2. 复制 constitution + registry 模板
3. 写入 active-workflow

### 第二步：快速分析 + 代码调研

并行执行：
1. 调用 @code-explorer 快速调研相关代码 → 口头输出关键文件/路径
2. TRAE Agent 读取 explorer 输出，结合用户描述，直接生成简化 requirements.md（3-5 条 AC，EARS 格式）

输出：`.specdev/specs/<slug>/requirements.md`

### 第三步：Human Gate 1 — 确认需求范围 🛑

1. 展示需求摘要 + 关键文件路径
2. 询问：「范围是否正确？确认后直接开始实施。」
3. 停止，等待确认。更新 `hg1: "passed"`

### 第四步：实施 → 审查 → 验证

1. @code-explorer：轻量调研当前代码状态（口头输出）
2. @implementer：按 requirements.md 实现
3. @reviewer：单视角审查（含 correctness + design + connectivity）
4. @verifier：独立验证

### 第五步：Human Gate 2 — 验收确认 🛑

展示验证结果，等待确认。完成后清理。

## 约束
- 不经过 Phase 拆分 — 适用于单次提交能完成的改动
- 不经过完整 HG-2 — design/plan 由 TRAE Agent 口头决策
- 仍有 implementer→reviewer→verifier 三阶段闭环
