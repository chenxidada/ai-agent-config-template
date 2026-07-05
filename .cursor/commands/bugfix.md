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

委托 `plan-generator`：
- 分析根因
- 设计修复方案
- 输出 `.specdev/specs/<slug>/design.md`（精简版，含修复方案和影响分析）

完成后 → 🛑 **HG-2**：向用户确认修复方案。

用户确认：`"hg2": "passed"` + `"current_phase": "phase-1-fix"`

### 第四步：实施 → 审查 → 验证（HG-2 确认后）

与 /feature 的 Phase 实施循环相同（implementer → reviewer → verifier），只运行一个 Phase。

完成后 → 🛑 **HG-3**：向用户报告结果。

用户确认：`"hg3": "passed"` → 完成清理（同 /feature 第九步）

---

## 约束

- 修复范围不能超出 bug 本身——不要「顺便重构」
- 必须有回归测试防止 bug 重现
- Human Gate 规则同 /feature
