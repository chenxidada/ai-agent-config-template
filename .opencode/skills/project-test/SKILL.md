---
name: project-test
description: >-
  Test knowledge: test framework, run commands, test environment, coverage tools,
  common test issues. Use when: running tests, writing tests, debugging test failures,
  setting up test environment. Trigger words: test, ctest, gtest, vitest, coverage,
  mock, stub, assert, expect.
---

## 项目测试技能

本文件由 validator agent 在项目开发过程中自动维护，implementer agent 交叉验证。
记录项目特有的测试知识，避免每次重新摸索。

**⚠️ 维护规则**：
- 每条知识有验证状态：✅ 已验证 / ⚠️ 已过期 / ❌ 未验证
- 错误或过期的条目标记为 ⚠️ 而非删除，保留历史但注明不再适用
- 同一事物的多条记录应合并，而非并列
- implementer 在运行测试时也应检查并更新测试知识

---

## 测试框架

> **状态说明**：✅=已验证可用 | ⚠️=已过期/不可用 | ❌=未验证

### Enforcement Gate Plugin 测试
- **状态**：✅ 已验证
- **测试类型**：独立 ES Module 脚本，无框架依赖
- **测试文件**：`.opencode/plugins/enforcement-gate.test.mjs`（实施者集成测试）
- **验证者独立测试**：`specs/validation/phase2-enforcement-plugin/test-scripts/validator-independent-verification.mjs`（43 个额外场景）
- **测试风格**：集成测试，mock ctx 对象 + 真实插件代码，验证 permission.ask 和 event 的外部行为
- **测试覆盖**：77 个实施者测试 + 43 个验证者独立测试 = 120 个测试用例，覆盖 Edit Gate、Bash Gate（allowlist + denylist）、Task Gate（discussion/execution）、Event Handlers、First-run、No API fallback、Compaction 状态恢复、Unknown type pass-through、参数变化检测、端到端行为验证、多 agent 数组分发、Windows 路径规范化、共存性验证
- **最后验证**：2026-06-16 by validator，120/120 passed（77 implementer + 43 validator）

---

## 运行命令

### `node .opencode/plugins/enforcement-gate.test.mjs`
- **状态**：✅ 已验证
- **环境**：Node.js 20.16.0
- **用途**：运行 enforcement gate 插件的完整集成测试（实施者编写）
- **输出**：每个测试用例的 pass/fail 状态，最终统计结果
- **退出码**：0（全部通过）/ 1（有失败）
- **最后验证**：2026-06-16 by validator

### `node specs/validation/phase2-enforcement-plugin/test-scripts/validator-independent-verification.mjs`
- **状态**：✅ 已验证
- **环境**：Node.js 20.16.0
- **用途**：运行验证者独立验证脚本，覆盖实施者未测试的场景（参数变化、边界条件、E2E 行为、SF1-SF3 验证）
- **输出**：43 个测试的 pass/fail 状态
- **退出码**：0（全部通过）/ 1（有失败）
- **最后验证**：2026-06-16 by validator

### ✅ 配置/Markdown 验证（Phase 3 合规验证）

| 项目 | 值 |
|------|-----|
| **状态** | ✅ 已验证 |
| **环境** | Linux, bash, git |
| **命令** | `bash specs/validation/test-scripts/verify-phase3-compliance.sh` |
| **说明** | 针对无编译/无运行时的 markdown 配置变更，通过 grep + diff + git log 验证内容正确性 |
| **最后验证** | 2026-06-16 |

### ✅ 通用 grep 模式检查

| 项目 | 值 |
|------|-----|
| **状态** | ✅ 已验证 |
| **环境** | Linux, bash |
| **命令** | `grep -r "<pattern>" .opencode/agents/` |
| **说明** | 验证 agent 定义文件中的特定内容是否存在 |
| **最后验证** | 2026-06-16 |

### ✅ Git 合规检查

| 项目 | 值 |
|------|-----|
| **状态** | ✅ 已验证 |
| **环境** | Linux, git |
| **命令** | `git log --all --oneline` / `git diff --name-only main..HEAD` / `git status --short` |
| **说明** | 验证非 specs 文件是否在 `impl-*` 分支上修改 |
| **最后验证** | 2026-06-16

---

## 测试环境配置

- 测试在临时目录（`os.tmpdir()`）中创建隔离环境，避免污染项目目录
- Mock `ctx` 对象提供 `directory` 和 `client.session.info` API
- 测试临时 `specs/current-status.md` 文件控制 mode/state
- 测试完成后自动清理临时目录

---

## 覆盖率工具

*（尚无覆盖率配置）*

---

## 常见问题与解决方案

*（尚无记录的测试问题）*

---

## 运行命令

### 文本规则验证脚本
- **命令**: `bash specs/validation/phase1-text-rule-hardening/test-scripts/verify-text-rules.sh`
- **状态**: ✅ 已验证
- **环境**: Linux, bash
- **说明**: 验证 Phase 1 文本规则硬化的 11 项修改是否正确应用于 4 个目标文件。基于 grep/sed 的自动化检查，共 33 项检查。
- **已知局限**: 部分 grep 正则可能因 Markdown 换行/格式变化产生误报，需手动复核。
- **最后验证**: 2026-06-16 by validator

---

## 注意事项

- 测试中用 `.mjs` 扩展名，确保 Node.js 以 ES Module 模式加载
- 测试的 `import` 路径与插件在实际框架中的加载路径一致（`./enforcement-gate.mjs`）
- 新增测试应在 `enforcement-gate.test.mjs` 的 `runIntegrationTests()` 函数中追加
- 验证者独立测试脚本从项目根目录运行，使用相对路径 `../../../../.opencode/plugins/enforcement-gate.mjs` 加载插件

### Phase 1: 文本规则硬化
- **状态**: ✅ 已验证
- **说明**: Phase 1（Enforcement System Text Rule Hardening）修改代理配置/规则文件，不涉及代码。无需代码级自动化测试 — 验证方式为内容审计（grep/sed 检查 + 手动比对设计文档）。后续 Phase 2/3 中通过行为观察确认规则是否被遵守。
- **最后验证**: 2026-06-16 by validator（implementer 首次记录后，validator 交叉验证并更新）
