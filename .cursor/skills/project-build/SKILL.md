---
name: project-build
description: >-
  Build/compile knowledge: commands, flags, dependency install, environment setup,
  common build errors and solutions. Use when: building, compiling, encountering
  build errors, changing build configuration, or installing dependencies.
  Trigger words: cmake, build, compile, make, ninja, gcc, clang, link, library, dependency.
---

## 项目构建技能

本文件由 implementer agent 在项目开发过程中自动维护，validator agent 交叉验证。
记录项目特有的构建知识，避免每次重新摸索。

**⚠️ 维护规则**：
- 每条知识有验证状态：✅ 已验证 / ⚠️ 已过期 / ❌ 未验证
- 错误或过期的条目标记为 ⚠️ 而非删除，保留历史但注明不再适用
- 同一事物的多条记录应合并，而非并列
- validator 在验证失败时也应检查并更新构建知识

---

## 构建命令

> **状态说明**：✅=已验证可用 | ⚠️=已过期/不可用 | ❌=未验证

### OpenCode 插件（.mjs）— 无需构建
- **状态**：✅ 已验证
- **环境**：Node.js 20.16.0
- **说明**：`.opencode/plugins/` 下的 `.mjs` 文件是纯 JavaScript ES Module，由 OpenCode 框架直接加载执行，无需编译或构建步骤。用到的 API 仅限于标准 Node.js 模块（`fs/promises`、`path`），无外部依赖。
- **文件**：`enforcement-gate.mjs`、`kb-sync-runtime.mjs`
- **最后验证**：2026-06-16 by implementer，Phase 2 enforcement plugin 加载测试通过

---

## 依赖安装

<!-- 格式同上，标注状态 + 环境 + 最后验证时间 -->

*（尚无已验证的依赖安装信息 — 插件使用标准 Node.js API，无需额外依赖）*

---

## 环境要求

### Node.js
- **状态**：✅ 已验证
- **版本**：v20.16.0（经 nvm 管理）
- **路径**：`/home/chendc/.nvm/versions/node/v20.16.0/bin/node`
- **最后验证**：2026-06-16 by implementer

<!-- 特殊环境变量、工具版本等，同样标注验证状态 -->

---

## 常见问题与解决方案

<!-- 遇到编译错误并解决后记录，标注问题现象 + 解决方案 + 验证状态 -->

*（尚无记录的构建问题）*

---

## 注意事项

### Phase 1: 文本规则硬化
- **状态**: ✅ 已验证
- **说明**: Phase 1（Enforcement System Text Rule Hardening）为纯文本配置变更，修改 `.opencode/agents/orchestrator.md`、`AGENTS.md`、`.opencode/snippets/escalation-protocol.md`、`.opencode/snippets/unified-pipeline.md`。无需编译/构建步骤。
- **最后验证**: 2026-06-16 by implementer

*（尚无特殊注意点）*
