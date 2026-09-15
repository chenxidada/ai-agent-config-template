---
description: 直接进入实施阶段（需HG-2已通过）
argument-hint: <可选：补充说明>
---

# /implement — 执行实施

当用户使用 `/implement` 时，执行当前 Phase 的 implementer→reviewer→verifier 闭环。

## 前置条件
- 当前活跃工作流必须存在
- `current-status.json` 中 HG-2 = `passed`
- Phase spec 文件必须存在

## 流程

### 第零步：Per-Phase Code Exploration

在 implementer 启动前，先调用 @code-explorer 调研当前 Phase 的代码上下文：

产出：
- `.specdev/specs/<slug>/phases/<current_phase>/repo-exploration.md`
- `.specdev/specs/<slug>/phases/<current_phase>/repo-exploration-zh.md`

内容包括：Key Entry Points、Likely Impact Surface、Existing Constraints、Stub Detection（交叉校验 tech-debt-registry）

### 第一步：implementer

调用 @implementer 实现 -> 更新 `tech-debt-registry.md`

**UI Phase（DAG `ui: true`）原型门禁**：implementer 会先只做静态原型并停止（输出 `## Prototype（待确认）`）。
此时**不要**继续派发 reviewer —— 先向用户展示原型截图并等待确认，确认后
`touch .specdev/specs/<slug>/phases/<current_phase>/.prototype-approved` 再调用 @implementer 续做。
（`pipeline-gate.sh` 会在标记缺失时程序化 deny reviewer/verifier 派发。）

### 第二步：并行四视角 Reviewer

同时调用 4 个 reviewer（并行执行）：

| Reviewer | 输出文件 | 视角 |
|----------|---------|------|
| @reviewer-correctness | `review-correctness.md` | 实现正确性：函数体有真实逻辑？空壳检测 |
| @reviewer-design | `review-design.md` | 设计一致性：是否遵循 architecture constraints？ |
| @reviewer-connectivity | `review-connectivity.md` | 集成连通性：数据路径完整可追踪？ |
| @reviewer-visual | `review-visual.md` | 视觉一致性：token / 组件复用 / 状态 / 断点 / a11y / 文案 / 反模式（非 UI Phase 返回 `N/A`） |

### 第三步：Merge 判决

读取 4 份并行审查报告，生成统一 `review.md`：

- 任一 reviewer 判定 MUST-FIX → 整体 MUST-FIX → loop_count+1 → 回到 implementer
- 任一 reviewer 报 CRITICAL → 整体 MUST-FIX
- 全都 PASS（或 `N/A`）→ 整体 PASS → 进入 verifier
- 有 SHOULD-FIX 无 MUST-FIX → 整体 SHOULD-FIX → 进入 verifier

> 🔴 `review.md` 判决行**必须只含单一值**（如 `## 判决：MUST-FIX`），
> 不得保留多值枚举 —— `parse_review_verdict` 会判为无可解析判决，导致 MUST-FIX 拦截失效。

### 第四步：verifier

调用 @verifier 独立验证 -> 输出 verification.md

**UI Phase**：verifier 强制执行视觉验证（基准对比 + 4 断点截图 + 状态矩阵截图 + console/network）。
视觉证据缺失 → 判决强制 PARTIAL 且标 `visual-blocking: true`。

### 第五步：Human Gate 3

展示验证结果（UI Phase 含视觉验证结论与 `visual-blocking` 标记），等待用户确认。

---

## 并行 Reviewer 判定规则

| correctness | design | connectivity | visual | 最终判决 |
|:--:|:--:|:--:|:--:|:--:|
| PASS | PASS | PASS | PASS | **PASS** |
| PASS | PASS | PASS | N/A | **PASS** |
| PASS | SHOULD-FIX | PASS | * | **SHOULD-FIX** |
| SHOULD-FIX | * | * | * | **SHOULD-FIX** |
| MUST-FIX | * | * | * | **MUST-FIX** |
| * | MUST-FIX | * | * | **MUST-FIX** |
| * | * | MUST-FIX | * | **MUST-FIX** |
| * | * | * | MUST-FIX | **MUST-FIX** |

判定优先级：`MUST-FIX` > `SHOULD-FIX` > `PASS` > `N/A`。`N/A` 表示「本视角不适用」，不参与合并加权。

## 约束
- 回路上限 2 轮（loop_count 程序化阻断）
- 并行 reviewer 不共享上下文 — 独立判断
- code-explorer 必须在每个 Phase 开始时重新运行
- UI Phase 未确认原型前不得派发 reviewer / verifier
- 不得把 `reviewer-visual` 的 `N/A` 当作 PASS 计入
