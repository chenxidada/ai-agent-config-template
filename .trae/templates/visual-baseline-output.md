# Visual Baseline Output Template

<!--
  此模板由 plan-generator 在 ui_relevant 的工作流中使用。
  输出：<spec_dir>/visual-baseline.md + <spec_dir>/visual-baseline-zh.md
  配套产物：design-system/<slug>/MASTER.md + design-system/<slug>/pages/<page>.md
  参考产物：design-refs/（用户提供的参考截图）

  存在意义：这是「视觉 ground truth」的冻结文件。
  HG-1.5 通过后，本文件即成为 implementer 写样式、reviewer-visual 查一致性、
  verifier 做视觉比对的唯一基准。基准不确定 = 无可比对的 target = 偏差无法被发现。

  ═══════════════════════════════════════════════════════════════════
  生成命令（plan-generator 必须执行，不可凭记忆手写设计系统）
  ═══════════════════════════════════════════════════════════════════
  详见 .trae/snippets/ui-skill-usage.md。

  为每个候选风格各执行一次（-p 后接项目 slug）：

    python3 .trae/skills/ui-ux-pro-max/scripts/search.py \
      "<产品类型> <行业> <风格关键词>" \
      --design-system --persist -p "<slug>"

  需要页面级差异时追加 --page：

    python3 .trae/skills/ui-ux-pro-max/scripts/search.py \
      "<产品类型> <行业> <风格关键词>" \
      --design-system --persist -p "<slug>" --page "users-list"

  落盘位置：design-system/<slug>/MASTER.md
            design-system/<slug>/pages/<page>.md（override）

  ⚠️ 生成命令的实际输出必须原样引用到本文件，禁止用「凭印象」的方式
     编造配色/字体值 —— 那会让基准本身不可信。
-->

## 1. 候选风格（2-3 套）

<!--
  每套候选必须包含：完整配色 token、字体、关键效果。
  数值来源 = ui-ux-pro-max 的实际输出，不是想象。
-->

### 候选 A：<风格名>

- **生成命令**：`python3 .trae/skills/ui-ux-pro-max/scripts/search.py "..." --design-system -p "<slug>"`
- **Pattern**：
- **Style**：
- **配色**：

| Token | 值 | 用途 |
|------|------|------|
| primary | `#` | 主按钮、链接、聚焦环 |
| secondary | `#` | 次要按钮、标签 |
| cta | `#` | 关键行动点 |
| background | `#` | 页面底色 |
| surface | `#` | 卡片/表格底色 |
| text | `#` | 正文 |
| text-muted | `#` | 辅助文字 |
| border | `#` | 分隔线、边框 |

- **字体**：<!-- 标题 / 正文，含 Google Fonts 或本地字体名 -->
- **关键效果**：
- **反模式（本风格需避免）**：

### 候选 B：<风格名>

<!-- 同上结构 -->

### 候选 C：<风格名>（可选）

<!-- 同上结构 -->

## 2. 推荐与选定

- **AI 推荐**：候选 <X>
- **推荐理由**：<!-- 结合产品类型/行业/用户群，2-3 句 -->
- **用户选定**：<!-- 候选 X / 候选 X + 候选 Y 的某个 token / 自定义 -->
- **用户调整意见**：<!-- 如「主色换成候选 B 的，字体用候选 A 的」 -->

> 🔴 若用户未在上方做出选择，HG-1.5 不得通过。基准不能是「待定」。

## 3. 冻结的 Design Tokens

<!-- HG-1.5 通过后，本表即为唯一真相源。implementer 禁止使用表外颜色/间距。 -->

| Token | 冻结值 | 来源 | 备注 |
|------|------|:--:|------|
| `--color-primary` | `#` | 候选 <X> | — |
| `--color-primary-hover` | `#` | 派生 | 亮度 -10% |
| `--color-danger` | `#` | 候选 <X> | 删除操作 |
| `--color-bg` | `#` | 候选 <X> | — |
| `--color-surface` | `#` | 候选 <X> | — |
| `--color-text` | `#` | 候选 <X> | — |
| `--color-text-muted` | `#` | 候选 <X> | 对比度 ≥ 4.5:1 |
| `--color-border` | `#` | 候选 <X> | — |
| `--radius-card` | `12px` | 候选 <X> | — |
| `--radius-button` | `8px` | 候选 <X> | — |
| `--space-block` | `24px` | 候选 <X> | 区块间距 |
| `--space-inline` | `16px` | 候选 <X> | 元素间距 |
| `--font-heading` | — | 候选 <X> | — |
| `--font-body` | — | 候选 <X> | — |
| `--font-size-body` | `14px` | 候选 <X> | 行高 1.5 |
| `--font-size-heading` | `20px` | 候选 <X> | — |
| `--row-height` | `44px` | 候选 <X> | 表格行高 |
| `--navbar-height` | `64px` | 候选 <X> | 移动端 56px |

**Token 落地方式**：<!-- Tailwind config 路径 / CSS 变量文件路径 / theme provider。由 code-explorer 提供现状，plan-generator 决定 -->
**落地文件**：<!-- 如 tailwind.config.ts 的 theme.extend.colors、src/styles/tokens.css -->

## 4. 参考图归档清单

<!-- 用户提供的参考图/网址，统一归档到 design-refs/ -->

| # | 文件 | 来源 | 参考维度 | 不参考维度 |
|:--:|------|------|------|------|
| R-1 | `design-refs/r1.png` | 用户提供 | 配色、卡片密度 | 导航结构 |
| R-2 | — | https://... | 表格 hover | — |

**参考冲突处理**：<!-- 当参考图与冻结 token 冲突时，以哪一方为准？默认：冻结 token 优先 -->

## 5. 页面级 Override 映射

<!-- design-system/<slug>/pages/<page>.md 与 ui-spec.md 页面 ID 的对应关系 -->

| 页面 ID | 页面名称 | Override 文件 | 与 MASTER 的差异 |
|:--:|------|------|------|
| P-1 | 用户列表页 | `design-system/<slug>/pages/users-list.md` | 表格区允许更小内边距（16px） |
| P-2 | 新建用户弹窗 | — | 无差异，继承 MASTER |

**Override 优先级**：页面级文件 > MASTER.md（与 ui-ux-pro-max 的层级检索规则一致）

## 6. 冻结声明

<!-- HG-1.5 通过后填写。这是本文件的核心契约。 -->

- **冻结时间**：
- **冻结版本**：v1
- **冻结范围**：design tokens（§3）+ 页面 override 映射（§5）+ 参考图（§4）

**变更规则**：冻结后任何 token 变更必须：
1. 在本文件「修订记录」中登记
2. 说明影响哪些已实现的页面
3. 经用户确认（HG 级决策）

**禁止行为**：
- ❌ implementer 在代码中硬编码 §3 表外的颜色/间距值
- ❌ 未经登记擅自修改 `design-system/` 下的文件
- ❌ verifier 在无基准的情况下自行判断「视觉看起来对」

## 7. 修订记录

| # | 日期 | 原值 | 改为 | 原因 | 影响页面 | 批准人 |
|:--:|------|------|------|------|------|------|
| — | — | — | — | — | — | — |

## 8. 建议的下一步

<!-- 通常：「将候选风格呈现给用户 → 等待 HG-1.5 视觉基准确认」 -->
