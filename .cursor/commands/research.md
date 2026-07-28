# /research — 深度代码调研

当用户使用 `/research <目标描述>` 时，对代码库进行深度调研，产出结构化分析报告。

## 适用场景
- 接手陌生项目/模块，需要理解现有架构
- 在 `/feature` 之前先摸清代码现状
- 验证某个技术假设是否可行
- 了解模块间依赖关系和影响面

## 与 /feature 的关系
- `/research` 可独立使用，也可作为 `/feature` 的前置步骤
- 产出文件可被后续的 requirement-analyst、plan-generator 直接读取

## 流程

### 第一步：初始化

1. 生成 slug（如 `/research 支付模块` → `research-payment-module`）
2. 创建 `.specdev/specs/<slug>/` 目录
3. 写入 `.specdev/active-workflow`

### 第二步：深度调研

委托 `code-explorer` 进行深度调研。

输入：用户的目标描述 + 调研范围提示
产出：
- `.specdev/specs/<slug>/repo-exploration.md` — 结构化调研报告（8 个标准章节）
- `.specdev/specs/<slug>/repo-exploration-zh.md` — 中文翻译版

### 第三步：向用户展示

1. 读取 repo-exploration.md
2. 用 10-15 句中文概括关键发现（模块结构、入口路径、影响面、风险点）
3. 询问：「调研是否足够？是否需要进一步深入某个模块？」

---

## repo-exploration.md 标准格式

| 章节 | 内容 |
|------|------|
| **Task Context** | 调研目标（一段） |
| **Repository Overview** | 语言、框架、包管理、目录结构 |
| **Most Relevant Areas** | 文件/目录 → 内容 → 为什么相关（表格） |
| **Key Entry Points / Call Paths** | 1-3 条关键调用路径（ASCII 流程图） |
| **Likely Impact Surface** | 哪些文件会受影响 |
| **Existing Constraints / Conventions** | 编码规范、架构模式、设计惯例 |
| **Risks / Unknowns** | CONFIRMED / HYPOTHESIS / UNKNOWN 分类 |
| **Uncertain / Unverified** | 签名存在但行为未验证的函数（表格） |
| **Recommended Next Reads** | 下游 agent 优先读哪些文件 |

## 约束
- code-explorer 是只读 agent，不修改代码
- 区分 confirmed fact 和 hypothesis
- 所有文件路径必须精确
