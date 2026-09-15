# /research — 深度代码调研

当用户使用 `/research <目标描述>` 时，对代码库进行深度调研，产出结构化分析报告。

## 适用场景
- 接手陌生项目/模块，需要理解现有架构
- 在 `/feature` 之前先摸清代码现状
- 验证某个技术假设是否可行
- 了解模块间依赖关系和影响面

## 与 /feature 的关系
- `/research` 可独立使用，也可作为 `/feature` 的前置步骤
- 产出文件可被后续的 `plan-generator` 直接读取（作为 `design.md`「现状依据」章节的来源）
- ⚠️ **`requirement-analyst` 不读它** —— 需求阶段只谈「要什么」，不引入代码现状
  （避免把设计约束提前混进需求；现状对需求的影响应在 HG-2 由 `plan-generator` 提出）
- 与 **Phase 级** `code-explorer` 调研的区别：本命令产出的是**工作流级**报告
  （现有架构 / 约定 / 集成点 / 可复用资产），Phase 级报告只聚焦单个 Phase 的实施范围

## 流程

### 第一步：初始化

1. 生成 slug（如 `/research 支付模块` → `research-payment-module`）
2. 创建 `.specdev/specs/<slug>/` 目录
3. 将 `.specdev/tech-debt-registry-template.md` 复制到 `.specdev/specs/<slug>/tech-debt-registry.md`
   （§9 桩检测需要交叉比对它；缺失会让「哪些是桩、哪些是实现」无法判定）
4. 写入 `.specdev/active-workflow`

### 第二步：深度调研

委托 `code-explorer` 进行深度调研（**workflow 模式**：不创建 `current-status.json`，
故 `current_phase` 为空 → 产物落在工作流级路径）。

输入：用户的目标描述 + 调研范围提示
产出：
- `.specdev/specs/<slug>/repo-exploration.md` — 结构化调研报告（10 个标准章节；`ui_relevant: true` 时追加 §11）
- `.specdev/specs/<slug>/repo-exploration-zh.md` — 中文翻译版

### 第三步：向用户展示

1. 读取 repo-exploration.md
2. 用 10-15 句中文概括关键发现（模块结构、入口路径、影响面、风险点）
3. 询问：「调研是否足够？是否需要进一步深入某个模块？」

---

## repo-exploration.md 标准格式

| 章节 | 内容 |
|------|------|
| **1. Task Context** | 调研目标（一段） |
| **2. Repository Overview** | 语言、框架、包管理、目录结构 |
| **3. Most Relevant Areas** | 文件/目录 → 内容 → 为什么相关（表格，标注 📊/👁 来源） |
| **4. Key Entry Points / Call Paths** | 1-3 条关键调用路径（ASCII 流程图） |
| **5. Likely Impact Surface** | 哪些文件会受影响（含风险等级） |
| **6. Existing Constraints / Conventions** | 编码规范、架构模式、设计惯例 |
| **7. Risks / Unknowns** | CONFIRMED / HYPOTHESIS / UNKNOWN 分类 |
| **8. Uncertain / Unverified** | 签名存在但行为未验证的函数（表格） |
| **9. Stub Detection & Registry Cross-Validation** | 与 `tech-debt-registry.md` 交叉比对（桩不能作为设计依据） |
| **10. Recommended Next Reads** | 下游 agent 优先读哪些文件 |
| **11. UI / Design System Inventory** | 仅 `ui_relevant: true`：组件库 / 样式方案 / 真实 token 值 / 可复用变体 / 硬编码热点 |

> 章节集与 `.cursor/agents/code-explorer.md` 的 Output 定义**必须一致**（10 章节 + §11）。

## 约束
- code-explorer 是只读 agent，不修改代码
- 区分 confirmed fact 和 hypothesis
- 所有文件路径必须精确
