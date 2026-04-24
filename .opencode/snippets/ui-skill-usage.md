# UI/UX Skill 协作指令片段

> 本片段由 Orchestrator 在派发 subagent 时**按需注入**，不进任何 agent 的默认上下文。
> 仅当任务涉及 UI / 前端 / 视觉时才会拼入派发 prompt，避免污染 backend / DevOps / 文档类任务。

---

## 通用约定

- Skill 物理位置：`.opencode/skills/ui-ux-pro-max/`
- 调用方式：subagent 直接 bash 调用脚本（**不依赖 LLM 自动 routing**），结果确定可复现
- 设计资产位置：项目根目录 `design-system/<project-slug>/`（MASTER.md + pages/）
- 设计资产应**提交进 git**，作为团队设计单一真源；不要写到 `.gitignore`

---

## 对 solution-architect

设计文档涉及可视界面时，先调用：

```bash
python3 .opencode/skills/ui-ux-pro-max/scripts/search.py \
  "<product-type> <industry> <style-keywords>" \
  --design-system --persist -p "<project-slug>"
```

将产出的 `design-system/<project-slug>/MASTER.md` 中的核心决策（pattern / style / colors / typography / anti-patterns）写入设计文档的"视觉系统"章节，**并在脚注标注 source CSV 行号**以便追溯。

页面级差异落到 `design-system/<project-slug>/pages/<page-slug>.md`，仅记录覆盖项。

---

## 对 implementer

写 UI 代码前**必须**：

1. 读 `design-system/<project-slug>/MASTER.md`
2. 检查 `design-system/<project-slug>/pages/<current-page>.md` 是否存在；存在则 page 覆盖 master
3. 颜色 / 字体 / 字号 / 间距 / 圆角 / 阴影必须引用 token，**不得自创色值或字号**
4. 引用 token 时在代码中以注释标注 source，例如：
   ```tsx
   className="bg-primary-500"  // MASTER.md primary, ref products.csv:42
   ```
5. 若发现 MASTER 不全，**先回到 architect 阶段补全**，不要凭直觉填空

---

## 对 reviewer

UI 评审时调用：

```bash
python3 .opencode/skills/ui-ux-pro-max/scripts/search.py \
  "<feature-keywords>" --domain ux
```

将返回的相关 UX guidelines 作为 checklist：

- `Severity = critical/high` → **must-fix**
- `Severity = medium` → should-fix
- `Severity = low` → 提示

输出评审报告时引用 guideline 名称 + CSV 行号，避免泛泛"注意可访问性"类反馈。

---

## 对 validator

UI 类验收：

1. 用 playwright 截图当前页面（`browser_take_screenshot`）
2. 通过 `browser_evaluate` 提取关键 DOM 节点的 computed style
3. 对照 `design-system/<project-slug>/MASTER.md` 中的 token 做断言：
   - 主色相符？
   - 字体家族相符？
   - 关键间距 / 圆角相符？
4. 任何视觉漂移作为 **fail**，并在 validation 报告附前后值对比

---

## 何时不要注入本片段

以下任务一律**不注入**：

- backend API / 数据库 / migration / schema 改动
- DevOps / CI / 部署配置 / 容器化
- 数据脚本 / ETL / 定时任务
- 文档 / README / 配置文件改写（非视觉）
- 性能优化（非视觉相关）
- 纯逻辑 bug fix（不涉及 UI 渲染）

混合任务（如"加 API 并在 UI 显示新字段"）：注入。
