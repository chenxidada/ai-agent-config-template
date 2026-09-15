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
   > ⚠️ **顺序不能颠倒**：必须先写 `active-workflow`，再初始化 `current-status.json`。
   > `pipeline-gate.sh` 会拒绝「无活跃工作流却写入状态文件」，但允许初始化路径
   > （状态文件不存在 + 全部 HG 为 pending + `current_phase` 为空）。写反会导致工作流无法启动。
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
   > `hg1_5` **不在此处预置** —— 它是可选字段，只在 requirement-analyst 判定 `ui_relevant: true` 后
   > 于 HG-1.5 阶段加入。纯后端工作流永远不会写入它（保证与存量工作流的形状一致）。
5. 将 `.specdev/constitution-template.md` 复制到 `.specdev/specs/<slug>/constitution.md`（如果目标目录中尚不存在该文件）
6. 将 `.specdev/tech-debt-registry-template.md` 复制到 `.specdev/specs/<slug>/tech-debt-registry.md`
   > ⚠️ 这个文件不是装饰：`pipeline-gate.sh` 在写 `hg3=passed` 时会校验它存在，且本 Phase 声明的每个
   > `@STUB(...)` 都必须能在其中找到条目，否则 **deny**。漏复制会导致 Phase 根本无法验收。
7. 将 `.specdev/ui-spec-template.md` 复制到 `.specdev/specs/<slug>/ui-spec.md`
   - requirement-analyst 判定 `ui_relevant: false` 时，该文件保持空骨架，后续阶段全部跳过 UI 检查
8. 更新 `.specdev/specs/workflows.json`（全局索引）：
   ```json
   { "<slug>": { "status": "active", "created": "...", "description": "..." } }
   ```

### 第二步：需求分析

委托 `requirement-analyst` 分析需求，输出：
- `.specdev/specs/<slug>/requirements.md`
- `.specdev/specs/<slug>/ui-spec.md`（**仅当 UI 相关性判定为 true**；含页面清单 / ASCII 布局骨架 / 状态矩阵 / 响应式行为）

完成后，**你必须主动停下**并向用户展示需求摘要，等待 HG-1 明确确认（没有 hook 会代你推进 —— subagentStop 推进 hook 已删除，见 `.cursor/hooks/CHANGELOG.md`）。

### 第三步：Human Gate 1 — 需求确认 🛑

1. 读取 `.specdev/specs/<slug>/requirements.md`
2. **若存在 `ui-spec.md`，一并读取**
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

委托 `plan-generator` 设计架构+拆分 Phase，输出：
- `.specdev/specs/<slug>/design.md`（含 **UI / Design System** 章节）
- `.specdev/specs/<slug>/phase-plan.md`（DAG JSON **每个 Phase 必须标注 `ui: true/false`**）
- `.specdev/specs/<slug>/phases/<phase-id>/spec.md`（每个 Phase 一个）

**UI 工作流额外产出**（任一 Phase `ui: true` 时强制执行）：
- `python3 .cursor/skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "<slug>"`
  → 落盘 `design-system/<slug>/MASTER.md` + `design-system/<slug>/pages/`
- `.specdev/specs/<slug>/visual-baseline.md`（2-3 套候选风格 + 冻结 token 表）

完成后，**必须由你主动进入 HG-1.5**：先展示视觉基准，用户选定后才走 HG-2。
（**没有 hook 会自动触发任何 Human Gate** —— subagentStop 推进 hook `pipeline-advance.sh` 已删除，
取而代之的 `drift-reminder.sh` 只会提醒漂移、绝不推进。）

### 第四点五步：Human Gate 1.5 — 视觉基准确认 🛑（仅 UI 工作流）

**触发条件**：plan-generator 产出 `visual-baseline.md`（即存在 UI 相关的 Phase）

1. 读取 `.specdev/specs/<slug>/visual-baseline.md`
2. 向用户展示 2-3 套候选风格的**实际差异**（配色 token / 字体 / Style / Pattern），不是抽象描述
3. 展示 `design-system/<slug>/MASTER.md` 的关键 token（主色 / 字体 / 圆角 / 间距）
4. 若用户提供了参考图，展示其**参考维度与不参考维度**
5. 询问：「选哪一套风格？有无需要调整的 token？确认后进入方案确认（HG-2）。」
6. **停止，等待用户明确选定**

用户确认后：
- 更新 `current-status.json`: `"hg1_5": "passed"`
- 在 `visual-baseline.md` §2 填写「用户选定」+「用户调整意见」，§3 逐值填写冻结 token 表，§6 填写冻结声明

> 🔴 **基准不得为「待定」**。用户未选定风格前，HG-1.5 不得通过。
> 为什么独立于 HG-2：架构错了要重跑设计，风格不喜欢只需换一套 design system 文件 ——
> 两者失败模式与纠偏成本差一个量级，合并会让审美决策被架构讨论淹没。

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

**0.5 创建 Phase 分支（强制，`pipeline-gate.sh` 会程序化校验）**：
```bash
git checkout main && git checkout -b impl-<phase-id>
```
- 分支名必须是 `impl-` + DAG JSON 中的 `id`（如 `impl-phase-1-p0-core`）
- 不在该分支上派发 implementer → **deny**
- 同一 Phase 的 MUST-FIX 回路**不要**重复创建，停在已有分支上即可

**1. implementer**：按 `phases/<phase>/spec.md` 实现代码
   - 输入：spec.md + design.md + **repo-exploration.md** + tech-debt-registry.md
   - **UI Phase 额外输入**：`ui-spec.md` + `visual-baseline.md` + `design-system/<slug>/MASTER.md`
   - 输出：`.specdev/specs/<slug>/phases/<phase>/implementation.md` + 更新 `tech-debt-registry.md`

**1.5 原型确认门禁（仅 `ui: true` 的 Phase）🛑**

DAG JSON 中该 Phase `ui: true` 时，implementer 会**先只做静态原型并停止**：

1. implementer 输出 `implementation.md` 的 `## Prototype（待确认）` 章节 + `prototypes/screenshots/`
2. **你读取该章节，向用户展示原型截图**（每页面 × 4 断点 × 必须状态）
3. 说明：布局骨架落实程度 / 使用的 design token / 待确认项
4. 询问：「视觉方向是否符合预期？有无需要调整的地方？」
5. 用户确认后：
   - `touch .specdev/specs/<slug>/phases/<phase>/.prototype-approved`
   - 重新委托 implementer（**续做**，不归档旧产物）→ 接入真实逻辑
6. 用户要求修改 → 重新委托 implementer（不带标记）继续调整原型 → 再次展示

> 🔴 标记创建前，**不得派发任何 reviewer / verifier** —— `pipeline-gate.sh` 会程序化 deny。
> 原型是整条链上最便宜的纠偏点：文字 → 原型是秒级的，原型 → 生产代码是昂贵的。

**2. 并行四视角 Reviewer**：同时委托 4 个 reviewer
   - `reviewer-correctness` → `review-correctness.md`（实现正确性）
   - `reviewer-design` → `review-design.md`（设计一致性）
   - `reviewer-connectivity` → `review-connectivity.md`（集成连通性）
   - `reviewer-visual` → `review-visual.md`（视觉一致性；非 UI Phase 返回 `N/A`）
   - 等 4 个全部完成后，按合并规则生成 `review.md` 统一判决
   - 如 **任一** MUST-FIX → 回到步骤 1（修复后重审，`loop_count` +1，最多 2 轮）
   - `N/A` 不参与合并加权（既是否决也不冲抵）

**3. verifier**：独立端到端验证（仅当合并判决 ≠ MUST-FIX）
   - 输出：`.specdev/specs/<slug>/phases/<phase>/verification.md` + 判决 + 验证脚本
   - **UI Phase 强制视觉验证**：Playwright MCP（或 bash 兜底）→ 基准对比表 + 4 断点截图 + 状态矩阵截图 + console/network 检查
     - 视觉证据缺失 → 判决强制 PARTIAL 且标 `visual-blocking: true`，**不得静默放行**
   - 如判决 FAIL → 回到步骤 1（修复后重审+重验，最多 2 轮）

完成后，**你必须主动停下并进入 HG-3**（没有 hook 会自动触发停止 —— `pipeline-advance.sh` 已删除）。

### 第七步：Human Gate 3 — Phase 完成确认 🛑

1. 读取验证报告
2. 报告：实现概要 + 审查结果（4 视角） + 验证判决
   - **UI Phase 追加**：工具可用性（MCP / bash 兜底 / 仅 curl）+ `visual-blocking` 标记 + 基准对比/断点/状态矩阵结论
3. 询问：「是否通过验收？进入下一个 Phase 还是需要修改？」
4. **停止，等待用户确认**

用户确认后，**同一轮内一次性完成**（不要拆成两次确认）：

1. 先展示改动清单：`git diff --stat` + `git status -s`（让用户看到将被提交的文件）
2. 提交 + 合并 + 删分支：
   ```bash
   touch /tmp/git-commit-allowed
   git add <上一步清单中显式列举的本 Phase 文件>   # 禁止 git add -A / .
   git commit -m "Phase <phase-id>: <改动概要>"
   git checkout main && git merge impl-<phase-id> && git branch -d impl-<phase-id>
   ```
   > `git commit` 会被 `shell-guard.sh` 拦为 `ask`（弹窗确认）。`/tmp/git-commit-allowed`
   > 是「事先同意」的快速通道，marker 新鲜时直接放行、不弹窗。
3. 更新 `current-status.json`：`"hg3": "passed"`, `"loop_count": 0`
4. KB 同步（异步，不阻塞）
5. 若是最后一个 Phase → 委托 `wiki` agent 更新 `docs/wiki/`

### 第七点五步：Phase Entry Gate — 债务继承确认（仅 Phase 2+）🛑

在进入下一个 Phase 前，**必须检查技术债**：

1. 读取 `.specdev/specs/<slug>/tech-debt-registry.md`
2. 筛选「目标Phase = 下一个Phase」且「阻塞 = 🔴」的条目
3. 向用户呈现：「上一个 Phase 遗留了以下技术债，需要在本 Phase 优先处理：」
4. 询问：「这些债务如何处理？a) 本 Phase 优先解决  b) 推迟  c) 取消」
5. **等待用户决策**
6. 根据决策更新 registry 中的目标Phase

### 第八步：继续下一个 Phase

Phase Entry Gate 通过后：
1. 更新 `current-status.json`（新 `current_phase` = DAG JSON 的 `id`、`hg3` 重置为 `pending`、`loop_count` 重置为 0）
2. **创建新分支**：`git checkout main && git checkout -b impl-<新 phase-id>`
3. 委托 `code-explorer` 探索代码库 → 开始步骤 6-7

直到所有 Phase 完成。

### 第九步：完成清理

最后一个 Phase 通过 HG-3 后：
1. 更新 `workflows.json` 中该 slug 状态为 `completed`
2. 清除 `.specdev/active-workflow`
3. 同步知识库

---

## 约束

- **绝对不允许**跳过任何 Human Gate（含 UI 工作流的 HG-1.5 与原型确认门禁）
- **绝对不允许**用户说「好的」「看看」「嗯」就当作 HG 通过——必须明确说「确认」「继续」
- **绝对不允许**在用户确认原型前派发 reviewer / verifier（UI Phase）
- 每个 Phase 的 implementer → reviewer → verifier 循环最多 2 轮
- 超过 2 轮 → 向用户报告问题并请求指导
