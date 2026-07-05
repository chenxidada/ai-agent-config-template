# /implement — 执行实施

当用户使用 `/implement` 时，执行当前 Phase 的 implementer→reviewer→verifier 闭环。

## 前置条件
- 当前活跃工作流必须存在
- `current-status.json` 中 HG-2 = `passed`
- Phase spec 文件必须存在

## 流程

### 第零步：Per-Phase Code Exploration

在 implementer 启动前，先委托 `code-explorer` 调研当前 Phase 的代码上下文：

产出：
- `.specdev/specs/<slug>/phases/<current_phase>/repo-exploration.md`
- `.specdev/specs/<slug>/phases/<current_phase>/repo-exploration-zh.md`

内容包括：Key Entry Points、Likely Impact Surface、Existing Constraints、Stub Detection（交叉校验 tech-debt-registry）

### 第一步：implementer

委托 `implementer` 实现 -> 更新 `tech-debt-registry.md`

### 第二步：并行三视角 Reviewer

同时委托 3 个 reviewer（并行执行）：

| Reviewer | 输出文件 | 视角 |
|----------|---------|------|
| `reviewer-correctness` | `review-correctness.md` | 实现正确性：函数体有真实逻辑？空壳检测 |
| `reviewer-design` | `review-design.md` | 设计一致性：是否遵循 architecture constraints？ |
| `reviewer-connectivity` | `review-connectivity.md` | 集成连通性：数据路径完整可追踪？ |

### 第三步：Merge 判决

读取 3 份并行审查报告，生成统一 `review.md`：

- 任一 reviewer 判定 MUST-FIX → 整体 MUST-FIX → loop_count+1 → 回到 implementer
- 任一 reviewer 报 CRITICAL → 整体 MUST-FIX
- 全都 PASS → 整体 PASS → 进入 verifier
- 有 SHOULD-FIX 无 MUST-FIX → 整体 SHOULD-FIX → 进入 verifier

### 第四步：verifier

委托 `verifier` 独立验证 -> 输出 verification.md

### 第五步：Human Gate 3

展示验证结果，等待用户确认。

---

## 并行 Reviewer 判定规则

| correctness | design | connectivity | 最终判决 |
|:--:|:--:|:--:|:--:|
| PASS | PASS | PASS | **PASS** |
| PASS | SHOULD-FIX | PASS | **SHOULD-FIX** |
| MUST-FIX | * | * | **MUST-FIX** |
| * | MUST-FIX | * | **MUST-FIX** |
| * | * | MUST-FIX | **MUST-FIX** |

## 约束
- 回路上限 2 轮（loop_count 程序化阻断）
- 并行 reviewer 不共享上下文 — 独立判断
- code-explorer 必须在每个 Phase 开始时重新运行
