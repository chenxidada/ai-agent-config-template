---
name: wiki
description: 维护项目 Wiki 文档。独立调用时全量扫描代码并更新 docs/wiki/；也可在 Feature 完成后由 pipeline 自动触发。
---

# /wiki 命令

## 用法

```
/wiki              — 全量扫描代码，生成或更新 docs/wiki/ 全部页面
/wiki update       — 同上（别名）
/wiki init         — 首次初始化，从零创建全部 wiki 页面
/wiki changelog    — 仅更新 changelog.md（快速模式）
```

## 触发流程

### 独立调用（/wiki 或 /wiki update）

```
用户输入 /wiki
  │
  ├─ 1. 扫描项目代码结构
  │     - 识别所有模块/包/目录
  │     - 分析技术栈、框架、依赖
  │
  ├─ 2. 读取现有 docs/wiki/（如存在）
  │     - 对比代码现状 vs 现有文档
  │     - 标记过时页面 + 缺失页面
  │
  ├─ 3. 委托 wiki agent
  │     - 传入：项目根路径、现有 wiki 路径、更新模式（full/incremental）
  │     - wiki agent 执行增量更新
  │
  └─ 4. 向用户报告更新结果
        - 更新了哪些页面
        - 新增了哪些页面
        - 当前覆盖率
```

### Pipeline 集成（Feature 完成后自动触发）

```
最后一个 Phase 的 HG-3 通过
  │
  ├─ commit + merge + 删分支（现有流程）
  ├─ KB 同步（现有流程）
  │
  └─ 委托 wiki agent（Pipeline 模式）
        - 传入：spec slug、所有 Phase 的 implementation.md 路径
        - wiki agent 读取产出 → 更新受影响页面 + 追加 changelog
```

## 调度者行为

### 独立调用时

1. 直接委托 `wiki` agent，模式 = `standalone`
2. wiki agent 完成后，向用户报告更新概要
3. **不涉及 Human Gate** — wiki 更新不阻塞任何流程

### Pipeline 触发时

1. 在最后 Phase HG-3 流程的末尾，委托 `wiki` agent，模式 = `pipeline`
2. 传入当前 feature slug
3. wiki agent 完成后，调度者在 HG-3 报告中附带一行："Wiki 已更新"
4. **非阻塞** — wiki 更新失败不阻塞 pipeline 推进

## 委托 wiki agent 的 dispatch 格式

### 独立模式

```
请更新项目 Wiki 文档。

模式：standalone
项目根目录：<project_root>
Wiki 目录：<project_root>/docs/wiki/

任务：
1. 扫描项目全部代码，识别模块结构
2. 对比现有 wiki 内容，找出过时/缺失的部分
3. 增量更新所有层级（L1-L4）
4. 更新 .wiki-status.json

要求：
- 所有图表使用 Mermaid 格式
- 内容尽可能详细，逐模块逐函数记录
- 中文书写，技术术语保持英文
```

### Pipeline 模式

```
请根据 Feature 开发产出更新项目 Wiki。

模式：pipeline
Feature slug：<slug>
Spec 目录：.specdev/specs/<slug>/
Wiki 目录：<project_root>/docs/wiki/

输入文件：
- .specdev/specs/<slug>/design.md
- .specdev/specs/<slug>/phases/*/implementation.md
- .specdev/specs/<slug>/tech-debt-registry.md

任务：
1. 读取以上文件，确定变更影响范围
2. 更新受影响的 L1/L2/L3/L4 页面
3. 追加 changelog.md 条目
4. 更新 .wiki-status.json

要求：
- 只更新受影响的页面，不重写未变更内容
- changelog 必须包含：日期、slug、概要、影响模块、遗留债务
- 所有新增图表使用 Mermaid 格式
```
