# Solution Design Output Template

<!--
  此模板由 plan-generator 在设计每个 Phase 的技术方案时使用。
  implementer 依赖此文档进行实现指导。
  reviewer 用它验证实现是否遵守设计。
  
  质量要求：implementer 读完此文档后，可以无歧义地开始实现。
-->

## 范围覆盖

<!-- 本设计覆盖哪个 Phase？引用 phase-plan.md 中驱动此设计的 Phase 定义 -->

## 架构摘要

<!-- 3-5 句话的高层技术方案。让读者快速理解整体思路 -->

## 核心实体 / 数据模型

<!-- 
  新增或修改的数据结构、类型、接口。
  包含字段名、类型、关系。
  
  示例：
  ```typescript
  interface ExportConfig {
    format: 'csv' | 'json';
    columns: string[];
    filters: FilterCriteria;
    maxRows?: number;
  }
  ```
-->

## API 域

<!-- 
  新增或修改的 API 端点、函数签名、组件接口。
  包含请求/响应形状。
-->

## UI / Design System（仅当本 Phase 标注 `ui: true` 时必填）

<!--
  🔴 本 Phase 的 DAG JSON 中 "ui": true 时，本章节为必填项，缺失即视为设计未完成。
     ui: false 时整节删除，不要留空标题。

  本章节是「界面长什么样」在设计层的唯一载体。内容全部来自已冻结的
  visual-baseline.md 与 requirements 阶段的 ui-spec.md —— 你只做「翻译」，
  不重新做视觉决策（视觉方向已在 HG-1.5 由用户确认）。

  上游输入（直接读取，不要转述）：
  - .specdev/specs/<slug>/ui-spec.md           ← 页面/布局骨架/状态矩阵/断点行为
  - .specdev/specs/<slug>/visual-baseline.md   ← 冻结 design tokens（唯一真相源）
  - design-system/<slug>/MASTER.md             ← ui-ux-pro-max 产出的设计系统
-->

### Design Token 引用（不复制值，只引用）

<!--
  🔴 关键约束：不要在本文件里抄一遍色值然后让 implementer 照着写。
  正确做法是声明「从哪个 token 文件导入」，implementer 直接用 token 变量。

  示例：
  - Token 来源：design-system/<slug>/MASTER.md §Colors / §Typography / §Spacing
  - 代码接入方式：`src/styles/tokens.css` 定义 CSS 变量，组件只用 `var(--color-primary)`
  - 禁止事项：组件内出现任何字面量 `#hex` / `rgb()` / 魔法 px 值
-->

### 页面 / 路由表

<!--
  每个页面一行。对应 ui-spec.md 的页面清单，但补上设计层信息（布局组件名）。

  | 路由 | 页面 | 布局组件 | 滚动容器 | ui-spec 布局骨架引用 |
  |------|------|---------|---------|-------------------|
  | /users | 用户列表 | UsersPageLayout | 表格区 | ui-spec.md §3.1 |
-->

### 组件清单（复用 or 新建）

<!--
  🔴 新建组件必须给出精确文件路径与 props 签名 —— implementer 不应即兴造组件。
  复用组件必须写明来源路径，避免重复造轮子。

  | 组件 | 新建/复用 | 路径 | Props / 变体 | 对应 ui-spec 组件项 |
  |------|:--:|------|------|------|
  | UserTable | 新建 | src/components/UserTable.tsx | `{ users: User[]; onPageChange: (p: number) => void }` | §5.1 |
  | Button | 复用 | src/components/ui/Button.tsx | 已有 variant: primary/secondary | §5.2 |
-->

### 状态覆盖表

<!--
  逐组件声明要实现哪些状态。对应 ui-spec.md §6 交互状态矩阵。
  🔴 缺一个状态 = 缺一个 AC，不得只写 "default"。

  | 组件 | default | loading | empty | error | disabled |
  |------|:--:|:--:|:--:|:--:|:--:|
  | UserTable | ✅ | ✅ | ✅ | ✅ | — |
-->

### 断点实现策略

<!--
  对应 ui-spec.md §7 响应式行为。写清「怎么实现」，不是「要适配」。
  必须落到具体手段：CSS Grid 列数变化 / 侧栏转抽屉 / 表格转卡片。

  | 断点 | 布局变化 | 实现手段 |
  |------|---------|---------|
  | 375px | 侧栏折叠为抽屉；表格转卡片列表 | `md:hidden` + 抽屉组件 |
  | 768px+ | 侧栏常驻 | `grid-cols-[240px_1fr]` |
-->

### 视觉反模式（禁止清单）

<!--
  从 design-system/<slug>/MASTER.md 的 Anti-patterns 章节摘录 + 本项目特有禁忌。
  implementer 违反任一 → reviewer-visual 判 🔴。

  示例：
  - ❌ 紫色渐变 + 居中大标题（AI 味过重）
  - ❌ 超过 3 种强调色
  - ❌ 卡片阴影超过 2 层级
-->

## 实现方案

<!--
  逐步骤描述如何实现本设计。
  足够具体，让 implementer 知道：
  - 要创建或修改哪些文件（精确路径）
  - 关键逻辑应该长什么样子（非平凡部分的骨架代码）
  - 组件之间如何连接
-->

### 文件产出计划

<!-- 
  关键：列出每个将被创建或修改的文件。
  这是 implementer 的主要工作清单。
  
  **新增文件：**
  ```
  src/modules/auth/
  ├── auth.module.ts
  ├── auth.service.ts
  ├── auth.controller.ts
  └── dto/
      ├── login.dto.ts
      └── register.dto.ts
  ```
  
  **修改文件：**
  ```
  src/app.module.ts — 导入 AuthModule
  ```
-->

### 关键骨架代码

<!-- 
  对关键的非平凡组件，提供骨架代码展示：
  - 类/函数签名
  - 核心逻辑流程（伪代码或简化的真实代码）
  - 重要的类型定义（DTO、接口）
  
  不写完整实现代码。写足够让 implementer 理解设计意图而不产生歧义。
  
  只对 NEW 或 COMPLEX 组件提供骨架代码。
-->

## Phase DAG 依赖

<!-- 当前 Phase 在 DAG 中的位置：依赖哪些 Phase、被哪些 Phase 依赖 -->

## 外部依赖

<!-- 
  需要的新库、服务或基础设施。
  
  示例：
  - bcrypt (npm) — 用于密码哈希
  - No new infrastructure required
-->

## 高风险子系统

<!-- 设计中较高风险或需要额外关注的部分 -->

## 权衡/替代方案

<!-- 考虑了哪些替代方案？为什么选择了当前方案？ -->

## 验收标准验证方案

<!-- 
  本条是关键 —— 它驱动整个 review 和 validation 流程。
  为下游 agent（reviewer, verifier）设计具体的验证场景。
  
  | ID | 类型 | 场景 | 预期结果 | 优先级 |
  |----|------|------|---------|:------:|
  | VP-1 | functional | 正常用户登录 | 重定向到仪表盘 | must |
  | VP-2 | boundary | 空密码 | 显示验证错误 | must |
  | VP-3 | error | 无效 Token | 返回 401 | must |
  | VP-4 | visual | 登录页面渲染正确 | 表单、logo、footer 显示 | should |

  ⚠️ visual 类型优先级规则（不可违反）：
  - 本 Phase `ui: true` → 所有 visual 验证项优先级 = **must**（verifier 缺视觉证据即判 PARTIAL
    并标 `visual-blocking: true`，不可静默放行）
  - 本 Phase `ui: false` → visual 验证项可省略或标 should

  若 `ui: true`，visual 验证项必须至少覆盖：
  - 每个页面的 4 个断点（375 / 768 / 1024 / 1440）截图
  - ui-spec.md §6 状态矩阵中每个非 default 状态的截图
  - 冻结 token 的实测值比对（基准值 vs 实测值）
-->

## 设计修订记录

<!-- 
  记录实现过程中对设计方案的批准变更。
  由 reviewer 在批准设计变更后填写。
-->

| # | 日期 | 原设计章节 | 修改为 | 批准人 | 偏差来源 |
|---|------|-----------|--------|--------|---------|
| — | — | — | — | — | — |

## 建议的下一步

<!-- 通常：「进入本 Phase 的实现阶段」 -->
