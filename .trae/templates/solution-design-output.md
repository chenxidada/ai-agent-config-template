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
