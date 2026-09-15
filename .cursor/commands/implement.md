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

### 第零点五步：创建 Phase 分支（强制）

```bash
git checkout main && git checkout -b impl-<current_phase>
```

- `pipeline-gate.sh` 在派发 implementer 时会校验当前分支 == `impl-<current_phase>`，不匹配即 **deny**
- 同一 Phase 的 MUST-FIX 回路**不重复创建**，停在已有分支上
- 方向性错误（方法/架构选错）才回 `main` → `git branch -D impl-<current_phase>` → 重建

### 第一步：implementer

委托 `implementer` 实现 -> 更新 `tech-debt-registry.md`

**UI Phase（DAG `ui: true`）原型门禁**：implementer 会先只做静态原型并停止（输出 `## Prototype（待确认）`）。
此时**不要**继续派发 reviewer —— 先向用户展示原型截图并等待确认，确认后
`touch .specdev/specs/<slug>/phases/<current_phase>/.prototype-approved` 再重新委托 implementer 续做。
（`pipeline-gate.sh` 会在标记缺失时程序化 deny reviewer/verifier 派发。）

### 第二步：并行四视角 Reviewer

同时委托 4 个 reviewer（并行执行）：

| Reviewer | 输出文件 | 视角 |
|----------|---------|------|
| `reviewer-correctness` | `review-correctness.md` | 实现正确性：函数体有真实逻辑？空壳检测 |
| `reviewer-design` | `review-design.md` | 设计一致性：是否遵循 architecture constraints？ |
| `reviewer-connectivity` | `review-connectivity.md` | 集成连通性：数据路径完整可追踪？ |
| `reviewer-visual` | `review-visual.md` | 视觉一致性：token / 组件复用 / 状态 / 断点 / a11y / 文案 / 反模式（非 UI Phase 返回 `N/A`） |

### 第三步：Merge 判决

读取 4 份并行审查报告，生成统一 `review.md`：

- 任一 reviewer 判定 MUST-FIX → 整体 MUST-FIX → loop_count+1 → 回到 implementer
- 任一 reviewer 报 CRITICAL → 整体 MUST-FIX
- 全都 PASS（或 `N/A`）→ 整体 PASS → 进入 verifier
- 有 SHOULD-FIX 无 MUST-FIX → 整体 SHOULD-FIX → 进入 verifier

> 🔴 `review.md` 判决行**必须只含单一值**（如 `## 判决：MUST-FIX`），
> 不得保留多值枚举 —— `parse_review_verdict` 会判为无可解析判决，gate 对此一律 **deny**，
> 会硬阻断 hg3 写入（不会静默放行）。
> 另注意 gate 的「自陈 + 证据」双判：合并报告自陈 PASS，但任何一份 `review-*.md`
> 原始报告的 Must-Fix 区有 🔴 时仍然 deny。

### 第四步：verifier

委托 `verifier` 独立验证 -> 输出 verification.md

**UI Phase**：verifier 强制执行视觉验证（基准对比 + 4 断点截图 + 状态矩阵截图 + console/network）。
视觉证据缺失 → 判决强制 PARTIAL 且标 `visual-blocking: true`。

### 第五步：Human Gate 3

展示验证结果（UI Phase 含视觉验证结论与 `visual-blocking` 标记），等待用户确认。

用户确认「通过」后，**同一轮内一次性完成**：commit → merge 回 main → 删分支
→ 更新 `current-status.json`（`hg3=passed`, `loop_count=0`）→ KB 同步（异步）。

```bash
touch /tmp/git-commit-allowed
git add <本 Phase 实际改动的文件（显式列举，禁止 -A / .）>
git commit -m "Phase <current_phase>: <概要>"
git checkout main && git merge impl-<current_phase> && git branch -d impl-<current_phase>
```

### 第六步：重跑某一步时（MUST-FIX 回路 / 用户要求重做）

重派上游会作废下游。派发前**必须**（只向下游，不向上游）：

1. 该步骤 `current-status.json` 状态 `completed` → `pending`，`loop_count` 归零
2. 级联作废下游：重跑 implementer → reviewer + verifier 置 `pending`；重跑 reviewer → verifier 置 `pending`
3. 【仅重跑 reviewer】若 `review.md` 已在直接路径，先由**你**归档到
   `phases/<phase>/.archive/review-<UTC时间戳>.md`（它是你合并出来的产物，不属任何 reviewer 的自清理边界）
4. 派发 → 各 agent 启动时自行把旧产物归档到 `.archive/`

> ❌ 不要用 git（reset/checkout/clean）来「清除」旧产物 —— 归档是 agent 的职责，git 会破坏分支隔离。

---

## 并行 Reviewer 判定规则

| correctness | design | connectivity | visual | 最终判决 |
|:--:|:--:|:--:|:--:|:--:|
| PASS | PASS | PASS | PASS | **PASS** |
| PASS | PASS | PASS | N/A | **PASS** |
| PASS | SHOULD-FIX | PASS | * | **SHOULD-FIX** |
| MUST-FIX | * | * | * | **MUST-FIX** |
| * | MUST-FIX | * | * | **MUST-FIX** |
| * | * | MUST-FIX | * | **MUST-FIX** |
| * | * | * | MUST-FIX | **MUST-FIX** |

优先级：`MUST-FIX` > `SHOULD-FIX` > `PASS` > `N/A`。`N/A` 不参与加权。

## 约束
- 回路上限 2 轮（loop_count 程序化阻断）
- 并行 reviewer 不共享上下文 — 独立判断
- code-explorer 必须在每个 Phase 开始时重新运行
- UI Phase 未经用户确认原型，不得派发 reviewer / verifier
