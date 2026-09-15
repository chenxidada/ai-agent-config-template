# UI Skill 调用规范（ui-ux-pro-max · Trae 侧）

> 本文件定义 Trae pipeline 中各 agent 如何调用 `ui-ux-pro-max` 技能。
> 技能本体：`.trae/skills/ui-ux-pro-max/SKILL.md`（含 67 风格 / 96 配色 / 57 字体 / 99 UX 准则 / 13 技术栈）。
>
> **背景**：本技能此前未被任何 `.trae/agents/` 引用（`grep` 零命中），
> 导致「已经躺在仓库里的设计智能」在 pipeline 中完全不可达。
> 本文件是接通它的唯一入口规范。

---

## 强制调用点

| Agent | 时机 | 调用方式 |
|------|------|------|
| `plan-generator` | `ui_relevant: true` 的工作流，设计阶段 | **必须**执行 `--design-system --persist`，产出 design system 与候选风格 |
| `implementer` | UI Phase 实现前 | 读取 `design-system/<slug>/MASTER.md` + 页面 override；**不自行调用**（token 已冻结） |
| `reviewer-visual` | 视觉审查时 | 可用 `--domain ux` / `--stack <stack>` 查询检查维度作为参考依据 |
| `verifier` | 视觉验证时 | 可选：用 `--domain ux` 查询无障碍/动效判据 |

**禁止**：orchestrator（TRAE Agent 调度者）自行加载本技能到自己的上下文——只由子 agent 调用。

## 调用方式

子 agent 通过**显式 bash** 调用，不依赖技能自动路由：

```bash
python3 .trae/skills/ui-ux-pro-max/scripts/search.py "<query>" [flags]
```

前置检查（仅首次需要）：

```bash
python3 --version    # 技能依赖 Python 3
```

---

## 命令速查

### 1. 生成完整设计系统（plan-generator 主用）

```bash
python3 .trae/skills/ui-ux-pro-max/scripts/search.py \
  "<产品类型> <行业> <风格关键词>" \
  --design-system --persist -p "<项目 slug>"
```

- `--design-system` / `-ds`：并行检索 product / style / color / landing / typography 五个域，套用 `ui-reasoning.csv` 的推理规则，返回完整设计系统
- `--persist`：落盘为 `design-system/<slug>/MASTER.md`（全局真相源）+ `design-system/<slug>/pages/`
- `-p`：项目名；会被 slug 化（小写、空格转连字符）作为目录名

**输出格式**：默认 ASCII 框（终端友好）；需写入文档时追加 `-f markdown`。

**页面级 override**（页面需要偏离 MASTER 时）：

```bash
python3 .trae/skills/ui-ux-pro-max/scripts/search.py \
  "<query>" \
  --design-system --persist -p "<slug>" --page "users-list"
```

生成 `design-system/<slug>/pages/users-list.md`。

**层级检索规则**：构建具体页面时，先查 `design-system/<slug>/pages/<page>.md`；存在则其规则**覆盖** `MASTER.md`，不存在则只用 `MASTER.md`。

### 2. 领域细查（补充检索）

```bash
python3 .trae/skills/ui-ux-pro-max/scripts/search.py "<关键词>" --domain <domain> [-n <max_results>]
```

| Domain | 用途 | 示例关键词 |
|------|------|------|
| `product` | 产品类型推荐 | SaaS, e-commerce, dashboard |
| `style` | UI 风格、配色、效果 | glassmorphism, minimalism, dark mode |
| `typography` | 字体搭配 | elegant, playful, professional |
| `color` | 按产品类型配色 | saas, fintech, healthcare |
| `landing` | 页面结构与 CTA 策略 | hero, pricing, social-proof |
| `chart` | 图表类型与库推荐 | trend, comparison, funnel |
| `ux` | 最佳实践与反模式 | animation, accessibility, z-index |
| `web` | Web 界面规范 | aria, focus, keyboard, semantic |

### 3. 技术栈规范（实现细节）

```bash
python3 .trae/skills/ui-ux-pro-max/scripts/search.py "<关键词>" --stack <stack>
```

可用 stack：`html-tailwind`（默认）、`react`、`nextjs`、`vue`、`svelte`、`shadcn`、`react-native`、`flutter`、`swiftui`、`jetpack-compose`。

---

## plan-generator 的完整使用流程

```
1. 读取 ui-spec.md（产品类型 / 行业 / 风格关键词 / 页面清单）
   │
2. 从关键词构造 2-3 组不同的 query（对应 2-3 套候选风格）
   │  例：同一产品用「professional enterprise」/「minimal clean」/「bold data-dense」
   │
3. 对每组 query 执行一次 --design-system --persist
   │  → 得到 2-3 套完整候选（配色 / 字体 / pattern / effects / anti-patterns）
   │
4. 对关键页面执行 --page 生成 override
   │
5. 把实际输出原样引用进 visual-baseline.md §1（禁止凭印象编造色值）
   │
6. 给出 AI 推荐 + 推荐理由 → 等待 HG-1.5 用户选定
```

**关键约束**：
- 候选之间的差异必须是**风格方向**的差异（不是同一风格的微调），否则用户的选择没有意义
- `visual-baseline.md` 中的 token 值必须是命令的真实输出，不可手写想象值 —— 基准不可信则整条视觉链失效
- 生成的文件**必须提交到仓库**（`design-system/` 不是临时产物，是团队共享的设计真相源）

---

## 常见错误

| 错误 | 后果 | 正确做法 |
|------|------|------|
| 凭记忆手写 design tokens | 基准不可信，verifier 无法比对 | 必须执行命令，引用真实输出 |
| 只生成一套候选 | 用户无从选择，HG-1.5 流于形式 | 生成 2-3 套风格方向不同的候选 |
| 用 `--design-system` 但不加 `--persist` | 输出只在终端，其他人看不到 | 必须 `--persist` 落盘 |
| 生成后不提交 `design-system/` | 下游 agent 读不到，退回即兴发挥 | 纳入 git 提交范围 |
| 为纯后端任务也调用本技能 | 污染上下文，浪费 token | 仅 `ui_relevant: true` 时调用 |

---

## 与 Playwright MCP 的分工

| 工具 | 职责 | 使用阶段 |
|------|------|------|
| `ui-ux-pro-max` | **设计决策**：风格 / 配色 / 字体 / 组件规范 | 设计阶段（plan-generator） |
| Playwright MCP | **视觉证据**：截图 / 断点验证 / console 检查 | 实施与验证阶段（implementer / verifier） |

前者回答「应该长什么样」，后者回答「实际长什么样」。两者缺一不可：
- 只有后者 → 能截图但不知道目标，verifier 的视觉判决是主观的
- 只有前者 → 有目标但没有证据，无法确认实现是否达成

Playwright MCP 配置见根目录 `.mcp.json`（Trae 侧无独立的 `.trae/mcp.json`，统一读取仓库根的 `.mcp.json`）。
