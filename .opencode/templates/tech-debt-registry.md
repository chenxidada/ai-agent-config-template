# 技术债注册表

> **本文档是项目中所有已知技术债的唯一来源。**
> 所有 Phase 的 agent 共写共读。写入新债，读取已有债，解决后更新状态。
> 位于 `specs/tech-debt-registry.md`。

---

## 活跃债务

<!--
  ID 格式：STUB-xxx（桩代码）/ GAP-xxx（功能缺失）/ DEBT-xxx（其他技术债）
  状态：🔴 阻塞 / 🟡 非阻塞
  类型：空实现 / 假返回值 / 流程骨架 / 条件桩 / 类型占位
  来源：impl-summary / review-report / scope-gap-report / validator

  结构化索引字段：
  - 标签：module:<name>, type:<stub|gap|debt>, concern:<topic>, bind:<binding>
    例：module:gateway, type:stub, concern:deliver, bind:someip
  - 依赖它的模块：哪些模块依赖这个接口。例：dds_gateway, mcu_agent
    标签 + 依赖 → agent 精确查询。例：查"标签含 gateway 的 🔴阻塞项"→ 2 条，不扫全表
-->

| ID | 源Phase | 模块 | 文件:函数:行号 | 当前行为 | 预期行为 | 类型 | 标签 | 依赖它的模块 | 目标Phase | 阻塞 | 来源 | 注册日期 |
|----|:------:|------|---------------|---------|---------|------|------|-------------|:--------:|:---:|------|---------|
| — | — | — | — | — | — | — | — | — | — | — | — | — |

## 已解决

| ID | 源Phase | 描述 | 解决Phase | 日期 | 验证方式 |
|----|:------:|------|:--------:|------|---------|
| — | — | — | — | — | — |

---

## 维护规则

### 谁写入
- **implementer**：创建桩代码后，新增行到「活跃债务」
- **reviewer**：发现 implementer 未标注的桩，新增行到「活跃债务」
- **validator**：变参测试发现疑似桩，新增行到「活跃债务」
- **orchestrator**（Phase Closure）：从 scope-gap-report 中同步延期项到注册表

### 谁读取
- **repo-explorer**（Phase Preparation）：读注册表，交叉验证代码中的桩
- **task-planner**：读注册表，将相关项纳入 sub-spec 计划
- **solution-architect**：读注册表，确认依赖接口是否在注册表中
- **implementer**：读注册表，不把桩当真实现
- **reviewer**：读注册表，已知桩跳过误报
- **validator**：读注册表，已知桩跳过行为验证

### 谁更新状态
- **implementer**：实现了之前标记的桩 → 从「活跃债务」移到「已解决」
- **reviewer**：确认桩已填好 → 更新状态
- **orchestrator**（Phase Closure）：标记不再适用的过时项 → ⚠️ 标记

### 格式要求
- 每个条目必须包含精确文件路径 + 函数名 + 行号
- 「当前行为」描述代码实际做什么，不是意图
- 解决时填写验证方式（变参测试 / 集成测试 / reviewer 确认）

### 标签规范
- 每个条目必须至少有 `module:` 和 `type:` 标签
- `concern:` 和 `bind:` 可选，尽可能填写以提高查询精度
- 标签使用英文小写，多词用连字符连接

### 查询指引
- **task-planner**：查目标Phase=N AND 阻塞=🔴 → 按标签分组
- **solution-architect**：查依赖它的模块含当前模块名
- **implementer**：查文件:函数精确匹配 → 已知桩不当真实现
- **reviewer**：查文件含当前目录前缀 → 已知桩不重复发现
- **validator**：查阻塞=🔴 且未在已解决表中
- **repo-explorer**：逐行按文件:函数:行号验证代码是否匹配

### 去重与清理
- 写入前搜索标签和文件:函数避免重复
- Phase Closure 时检查文件路径/函数名是否变化 → 标记 ⚠️ 或更新
