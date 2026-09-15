---
description: 启动完整新功能开发流程（多Phase + 并行审查）
argument-hint: <功能描述>
---

# /feature — 新功能开发流程

当用户使用 `/feature <描述>` 时，启动 spec 驱动的开发流程。

## 流程

### 第一步：创建工作流

1. 从用户描述中提取关键词生成 slug（如 `/feature 用户登录` → `user-login`）
2. 创建目录结构：
   ```
   .specdev/specs/<slug>/
   ├── phases/
   ├── current-status.json
   └── ...
   ```
3. 写入 `.specdev/active-workflow`（内容：工作流 slug）
4. 初始化 `current-status.json`：
   ```json
   {
     "slug": "<slug>",
     "description": "<用户描述>",
     "created": "<ISO timestamp>",
     "current_stage": "requirement-analysis",
     "current_phase": "",
     "loop_count": 0,
     "human_gates": {
       "hg1": "pending",
       "hg2": "pending",
       "hg3": "pending"
     },
     "phases": {},
     "last_update": "<ISO timestamp>"
   }
   ```
4. 将 `.specdev/constitution-template.md` 复制到 `.specdev/specs/<slug>/constitution.md`（如果目标目录中尚不存在该文件）
5. 将 `.specdev/tech-debt-registry-template.md` 复制到 `.specdev/specs/<slug>/tech-debt-registry.md`
6. 将 `.specdev/ui-spec-template.md` 复制到 `.specdev/specs/<slug>/ui-spec.md`
   - requirement-analyst 判定 `ui_relevant: false` 时，该文件保持空骨架，后续阶段全部跳过 UI 检查
7. 更新 `.specdev/specs/workflows.json`（全局索引）：
   ```json
   { "<slug>": { "status": "active", "created": "...", "description": "..." } }
   ```

> `hg1_5` **不在此处预置** —— 它是可选字段，只在 requirement-analyst 判定 `ui_relevant: true` 后
> 于 HG-1.5 阶段加入。纯后端工作流永远不会写入它（保证与存量工作流的形状一致）。

### 第二步：需求分析

调用 @requirement-analyst 分析需求，输出：
- `.specdev/specs/<slug>/requirements.md`
- `.specdev/specs/<slug>/ui-spec.md`（**仅当 UI 相关性判定为 true**；含页面清单 / ASCII 布局骨架 / 状态矩阵 / 响应式行为）

完成后，`pipeline-advance.sh` hook 会触发 HG-1 停止。

### 第三步：Human Gate 1 — 需求确认 🛑

1. 读取 `.specdev/specs/<slug>/requirements.md`
2. **若存在 `.specdev/specs/<slug>/ui-spec.md`，一并读取**
3. 用 5-8 句中文向用户概括需求
4. **UI 相关时额外展示**（缺一不可，否则 HG-1 不得通过）：
   - 页面/路由清单（§1）
   - **布局骨架 ASCII**（§3，桌面 + 移动）
   - **交互状态矩阵**（§5，含 loading / empty / error）
   - 响应式行为（§6，逐断点）
   - **视觉参考状态**（§8）——并主动问用户：「有参考的界面吗？可以给截图或网址」
5. 询问：「需求是否正确？是否需要补充？**UI 规格是否准确？**确认后进入架构设计阶段。」
6. **停止，等待用户明确确认**

用户确认后：更新 `current-status.json` 中 `"hg1": "passed"`

> 🔴 UI 工作流质检：`ui-spec.md` 中若出现「美观 / 现代 / 简洁 / 大方 / 流畅 / 响应式适配 / 体验好」
> 这类**无法验收的抽象形容词**，说明 requirement-analyst 未完成工作 ——
> 退回重写为具体值（色值 / px / 断点行为），不要带着模糊需求进入 HG-1。

### 第四步：架构设计（HG-1 确认后）

调用 @plan-generator 设计架构+拆分 Phase，输出：
- `.specdev/specs/<slug>/design.md`（含 **UI / Design System** 章节）
- `.specdev/specs/<slug>/phase-plan.md`（DAG JSON **每个 Phase 必须标注 `ui: true/false`**）
- `.specdev/specs/<slug>/phases/<phase-id>/spec.md`（每个 Phase 一个）

**UI 工作流额外产出**（任一 Phase `ui: true` 时强制执行）：
- `python3 .trae/skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "<slug>"`
  → 落盘 `design-system/<slug>/MASTER.md` + `design-system/<slug>/pages/`
- `.specdev/specs/<slug>/visual-baseline.md`（2-3 套候选风格 + 冻结 token 表）

完成后，hook 自动触发：**UI 工作流先 HG-1.5，再 HG-2**。

### 第四点五步：Human Gate 1.5 — 视觉基准确认 🛑（仅 UI 工作流）

> 纯后端工作流（`ui_relevant: false`）跳过本步，直接进入第五步。

1. 读取 `.specdev/specs/<slug>/visual-baseline.md`
2. 向用户展示 2-3 套候选风格的**实际差异**（配色 token / 字体 / Style / Pattern），不是抽象描述
3. 展示 `design-system/<slug>/MASTER.md` 的关键 token（主色 / 字体 / 圆角 / 间距）
4. 若用户提供了参考图，展示参考图的**参考维度与不参考维度**
5. 询问：「选哪一套风格？有无需要调整的 token？确认后进入方案确认（HG-2）。」
6. **停止，等待用户明确选定**

用户确认后：
- 更新 `current-status.json`: `"hg1_5": "passed"`
- 在 `visual-baseline.md` §2 填写「用户选定」+「用户调整意见」
- 在 §3 逐值填写「冻结的 Design Tokens」表
- 在 §6 填写冻结声明

> 🔴 基准不得为「待定」。用户未选定风格前，HG-1.5 不得通过。
> `pipeline-gate.sh` 会在标记 `hg1_5=passed` 时程序化校验 `visual-baseline.md` 已冻结 + `design-system/` 已生成。
> ➜ HG-1.5 通过后**不要跳过 HG-2**。

### 第五步：Human Gate 2 — 方案确认 🛑

1. 读取 `.specdev/specs/<slug>/design.md` 和 `phase-plan.md`
2. 展示：
   - 架构决策（2-3 个关键决策及理由）
   - Phase 拆分表格
   - 关键技术选型
3. 询问：「方案是否合理？确认后开始实施 Phase 1。」
4. **停止，等待用户明确说「确认」「开始实施」**

用户确认后：更新 `current-status.json` 中 `"hg2": "passed"` + `"current_phase": "phase-1-xxx"`

### 第六步：Phase 实施（HG-2 确认后）

对每个 Phase（从 Phase 1 开始）：

**0. Per-Phase Code Exploration（每个 Phase 前强制执行）**：
调用 @code-explorer 调研当前代码库状态。
- 产出：`phases/<phase>/repo-exploration.md`（10-section 结构化报告；`ui: true` 追加 §11 UI / Design System Inventory）+ `repo-exploration-zh.md`
- implementer/reviewer/verifier 必须读取此报告

**1. implementer**：按 `phases/<phase>/spec.md` 实现代码
   - 输入：spec.md + design.md + **repo-exploration.md** + tech-debt-registry.md
   - 输出：`.specdev/specs/<slug>/phases/<phase>/implementation.md` + 更新 `tech-debt-registry.md`
   - **UI Phase（DAG `ui: true`）原型门禁**：implementer 会先只做静态原型并停止（输出 `## Prototype（待确认）`）。
     此时**不要**继续派发 reviewer —— 先向用户展示原型截图并等待确认，确认后
     `touch .specdev/specs/<slug>/phases/<current_phase>/.prototype-approved` 再调用 @implementer 续做。
     （`pipeline-gate.sh` 会在标记缺失时程序化 deny reviewer/verifier 派发。）

**2. 并行四视角 Reviewer**：同时调用 4 个 reviewer
   - @reviewer-correctness → `review-correctness.md`（实现正确性）
   - @reviewer-design → `review-design.md`（设计一致性）
   - @reviewer-connectivity → `review-connectivity.md`（集成连通性）
   - @reviewer-visual → `review-visual.md`（视觉一致性；非 UI Phase 返回 `N/A`，`N/A` 不等于 PASS）
   - 等 4 个全部完成后，按合并规则生成 `review.md` 统一判决
   - 如 **任一** MUST-FIX → 回到步骤 1（修复后重审，`loop_count` +1，最多 2 轮）

> 🔴 `review.md` 判决行**必须只含单一值**（如 `## 判决：MUST-FIX`），
> 不得保留多值枚举 —— `parse_review_verdict` 会判为无可解析判决，导致 MUST-FIX 拦截失效。

**3. verifier**：独立端到端验证（仅当合并判决 ≠ MUST-FIX）
   - 输出：`.specdev/specs/<slug>/phases/<phase>/verification.md` + 判决 + 验证脚本
   - **UI Phase**：verifier 强制执行视觉验证（基准对比 + 4 断点截图 + 状态矩阵截图 + console/network）。
     视觉证据缺失 → 判决强制 PARTIAL 且标 `visual-blocking: true`
   - 如判决 FAIL → 回到步骤 1（修复后重审+重验，最多 2 轮）

完成后，hook 自动触发 HG-3 停止。

### 第七步：Human Gate 3 — Phase 完成确认 🛑

1. 读取验证报告
2. 报告：实现概要 + 审查结果（4 视角判决）+ 验证判决
   - **UI Phase 追加**：工具可用性（MCP / bash 兜底 / 仅 curl）+ `visual-blocking` 标记 + 视觉基准对比/断点矩阵/状态矩阵的结论
     - `visual-blocking: true` → **必须明确告知用户「视觉维度未被验证」**，不得静默略过
3. 询问：「是否通过验收？进入下一个 Phase 还是需要修改？」
4. **停止，等待用户确认**

用户确认后：更新 `current-status.json` — `"hg3": "passed"`, `"loop_count": 0`

### 第七点五步：Phase Entry Gate — 债务继承确认（仅 Phase 2+）🛑

在进入下一个 Phase 前，**必须检查技术债**：

1. 读取 `.specdev/specs/<slug>/tech-debt-registry.md`
2. 筛选「目标Phase = 下一个Phase」且「阻塞 = 🔴」的条目
3. 向用户呈现：「上一个 Phase 遗留了以下技术债，需要在本 Phase 优先处理：」
4. 询问：「这些债务如何处理？a) 本 Phase 优先解决  b) 推迟  c) 取消」
5. **等待用户决策**
6. 根据决策更新 registry 中的目标Phase

### 第八步：继续下一个 Phase

Phase Entry Gate 通过后，更新 `current-status.json`（新 `current_phase`, `hg3` 重置为 `pending`, `loop_count` 重置为 0），调用 @code-explorer 探索代码库 → 开始步骤 6-7。直到所有 Phase 完成。

### 第九步：完成清理

最后一个 Phase 通过 HG-3 后：
1. 更新 `workflows.json` 中该 slug 状态为 `completed`
2. 清除 `.specdev/active-workflow`
3. 同步知识库

---

## 约束

- **绝对不允许**跳过任何 Human Gate
- **绝对不允许**用户说「好的」「看看」「嗯」就当作 HG 通过——必须明确说「确认」「继续」
- **绝对不允许** UI 工作流跳过 HG-1.5（风格未定就实施 = 把审美决策推给 implementer）
- **绝对不允许** UI Phase 在用户确认原型前派发 reviewer / verifier
- **绝对不允许**以「用户没提风格要求」为由跳过 HG-1.5（无偏好 ≠ 无需选择）
- **绝对不允许**把 `reviewer-visual` 的 `N/A` 当作 PASS 计入合并判决
- 每个 Phase 的 implementer → reviewer → verifier 循环最多 2 轮
- 超过 2 轮 → 向用户报告问题并请求指导
