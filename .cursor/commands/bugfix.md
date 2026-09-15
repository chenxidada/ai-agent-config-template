# /bugfix — Bug 修复流程

当用户使用 `/bugfix <问题描述>` 时，启动 bug 修复流程。

## 与 /feature 的区别

Bug 修复流程简化了架构设计阶段（不需要完整的 Phase 拆分），但仍保留 spec 和 Human Gate。

## 流程

### 第一步：创建工作流

1. 生成 slug（如 `/bugfix 登录失败` → `fix-login-failure`）
2. 创建目录 + 初始化 `.specdev/specs/<slug>/current-status.json`（同 /feature）
3. 复制 `.specdev/constitution-template.md` → `.specdev/specs/<slug>/constitution.md`
4. 复制 `.specdev/tech-debt-registry-template.md` → `.specdev/specs/<slug>/tech-debt-registry.md`
5. 写入 `.specdev/active-workflow`
6. 更新 `.specdev/specs/workflows.json`

### 第二步：问题分析

委托 `requirement-analyst`：
- 分析 bug 影响范围
- 定义修复的验收标准
- 输出 `.specdev/specs/<slug>/requirements.md`

完成后 → 🛑 **HG-1**：向用户确认问题理解和修复范围。

用户确认：`"hg1": "passed"`

### 第三步：修复方案（HG-1 确认后）

**先调研，再分析根因** —— 根因分析必须基于代码实际状态，不能凭 bug 描述推断。

委托 `code-explorer`（**workflow 模式**，此时 `current_phase` 为空）：
- 产出 `.specdev/specs/<slug>/repo-exploration.md`
- 重点：疑似出问题的调用链、相关函数的**实际实现**（而非签名）、已有测试覆盖情况、相关桩代码

委托 `plan-generator`：
- 读取 requirements.md + **repo-exploration.md**
- 分析根因（必须引用 `repo-exploration.md` 中的具体位置，形如 `文件:行号`）
- 设计修复方案
- 输出 `.specdev/specs/<slug>/design.md`（精简版，含 **现状依据** 章节 + 修复方案 + 影响分析）

> 若 `plan-generator` 返回「⏸ STOP & EXPLORE」→ 再次派 `code-explorer` → **续做**。

完成后 → 🛑 **HG-2**：向用户确认修复方案。

用户确认：`"hg2": "passed"` + `"current_phase": "phase-1-fix"`
> 门禁会在写入 `hg2=passed` 时校验 `design.md` 的「现状依据」章节（L1–L5）

### 第四步：实施 → 审查 → 验证（HG-2 确认后）

与 /feature 的 Phase 实施循环相同（implementer → reviewer → verifier），只运行一个 Phase。

完成后 → 🛑 **HG-3**：向用户报告结果。

用户确认：`"hg3": "passed"` → 完成清理（同 /feature 第九步）

---

## 约束

- 修复范围不能超出 bug 本身——不要「顺便重构」
- 必须有回归测试防止 bug 重现
- Human Gate 规则同 /feature
