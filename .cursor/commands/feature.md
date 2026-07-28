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
6. 更新 `.specdev/specs/workflows.json`（全局索引）：
   ```json
   { "<slug>": { "status": "active", "created": "...", "description": "..." } }
   ```

### 第二步：需求分析

委托 `requirement-analyst` 分析需求，输出 `.specdev/specs/<slug>/requirements.md`。

完成后，`pipeline-advance.sh` hook 会触发 HG-1 停止。

### 第三步：Human Gate 1 — 需求确认 🛑

1. 读取 `.specdev/specs/<slug>/requirements.md`
2. 用 5-8 句中文向用户概括需求
3. 询问：「需求是否正确？是否需要补充？确认后进入架构设计阶段。」
4. **停止，等待用户明确确认**

用户确认后：更新 `current-status.json` 中 `"hg1": "passed"`

### 第四步：架构设计（HG-1 确认后）

委托 `plan-generator` 设计架构+拆分 Phase，输出：
- `.specdev/specs/<slug>/design.md`
- `.specdev/specs/<slug>/phase-plan.md`
- `.specdev/specs/<slug>/phases/<phase-id>/spec.md`（每个 Phase 一个）

完成后，hook 自动触发 HG-2 停止。

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
委托 `code-explorer` 调研当前代码库状态。
- 产出：`phases/<phase>/repo-exploration.md`（10-section 结构化报告）+ `repo-exploration-zh.md`
- implementer/reviewer/verifier 必须读取此报告

**1. implementer**：按 `phases/<phase>/spec.md` 实现代码
   - 输入：spec.md + design.md + **repo-exploration.md** + tech-debt-registry.md
   - 输出：`.specdev/specs/<slug>/phases/<phase>/implementation.md` + 更新 `tech-debt-registry.md`

**2. 并行三视角 Reviewer**：同时委托 3 个 reviewer
   - `reviewer-correctness` → `review-correctness.md`（实现正确性）
   - `reviewer-design` → `review-design.md`（设计一致性）
   - `reviewer-connectivity` → `review-connectivity.md`（集成连通性）
   - 等 3 个全部完成后，按合并规则生成 `review.md` 统一判决
   - 如 **任一** MUST-FIX → 回到步骤 1（修复后重审，`loop_count` +1，最多 2 轮）

**3. verifier**：独立端到端验证（仅当合并判决 ≠ MUST-FIX）
   - 输出：`.specdev/specs/<slug>/phases/<phase>/verification.md` + 判决 + 验证脚本
   - 如判决 FAIL → 回到步骤 1（修复后重审+重验，最多 2 轮）

完成后，hook 自动触发 HG-3 停止。

### 第七步：Human Gate 3 — Phase 完成确认 🛑

1. 读取验证报告
2. 报告：实现概要 + 审查结果 + 验证判决
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

Phase Entry Gate 通过后，更新 `current-status.json`（新 `current_phase`, `hg3` 重置为 `pending`, `loop_count` 重置为 0），委托 `code-explorer` 探索代码库 → 开始步骤 6-7。直到所有 Phase 完成。

### 第九步：完成清理

最后一个 Phase 通过 HG-3 后：
1. 更新 `workflows.json` 中该 slug 状态为 `completed`
2. 清除 `.specdev/active-workflow`
3. 同步知识库

---

## 约束

- **绝对不允许**跳过任何 Human Gate
- **绝对不允许**用户说「好的」「看看」「嗯」就当作 HG 通过——必须明确说「确认」「继续」
- 每个 Phase 的 implementer → reviewer → verifier 循环最多 2 轮
- 超过 2 轮 → 向用户报告问题并请求指导
