---
name: project-test
description: >-
  Test knowledge: test framework, run commands, test environment, coverage tools,
  common test issues. Use when: running tests, writing tests, debugging test failures,
  setting up test environment. Trigger words: test, ctest, gtest, vitest, coverage,
  mock, stub, assert, expect.
---

## 项目测试技能

本文件由 verifier agent 在项目开发过程中自动维护，implementer agent 交叉验证。
记录项目特有的测试知识，避免每次重新摸索。

**⚠️ 维护规则**：
- 每条知识有验证状态：✅ 已验证 / ⚠️ 已过期 / ❌ 未验证
- 错误或过期的条目标记为 ⚠️ 而非删除，保留历史但注明不再适用
- 同一事物的多条记录应合并，而非并列
- implementer 在运行测试时也应检查并更新测试知识

---

## 测试框架

> **状态说明**：✅=已验证可用 | ⚠️=已过期/不可用 | ❌=未验证

- ✅ **bash hook 无框架，用 fixture dry-run 验证**（2026-08-24 verified，Phase 3）。本项目「代码」是 `.trae/hooks/*.sh` bash 脚本 + agent `.md` 定义，无编译/单元测试框架。验证方式：
  1. `bash -n <script>.sh` 做语法检查（syntax-only，不执行）。
  2. **单元级**：`source` 共享库后直接调函数，比对不同输入的输出（防桩）。
  3. **集成级**：构造 stdin JSON payload 用管道喂给 hook，观察 stdout（`permissionDecision`）与退出码。

---

## 运行命令

- ✅ **verdict-parse.sh 三函数单元 dry-run**（2026-08-24 verified）：
  ```bash
  bash .specdev/specs/pipeline-verification-hardening/phases/phase-3-class-c-gate-hardening/test-scripts/unit-verdict-parse.sh
  ```
- ✅ **pipeline-gate.sh HG-3 门禁集成 dry-run**（2026-08-24 verified）：
  ```bash
  bash .specdev/specs/pipeline-verification-hardening/phases/phase-3-class-c-gate-hardening/test-scripts/integration-gate-dryrun.sh
  ```
- ✅ **语法检查**：`bash -n .trae/hooks/pipeline-gate.sh`

---

## 测试环境配置

*（项目首次使用时由 verifier 填充）*

---

## 覆盖率工具

*（项目首次使用时由 verifier 填充）*

---

## 常见问题与解决方案

- ✅ **喂 pipeline-gate.sh 做 HG-3 dry-run 需齐备前置文件**（2026-08-24，Phase 3）。`hg3=passed` 分支在到达 verifier 判决 ask 校验前，先跑 3 个 `check_file_valid` deny：
  - `implementation.md` 需 **≥10 行**且含 `##` 标记；
  - `review.md` 需 ≥5 行且含 `判决` 关键字，且判决非 `MUST-FIX`；
  - `verification.md` 需 ≥5 行。
  fixture 若行数不足会先被前置 deny 拦截（exit 2），永远到不了 ask 校验 → 误判为「ask 没生效」。构造沙盒时务必让三文件全部有效。
- ✅ **区分 ask 与 deny 的判定**（2026-08-24）：`ask()` 输出 JSON 含 `"permissionDecision":"ask"` 且 `exit 0`；`deny()` 写 stderr 且 `exit 2`。dry-run 判定用退出码 2→deny，stdout 含 ask 串→ask，否则 allow。捕获 stderr（`2>/dev/null` 会吞掉 deny 文案）才能定位前置 deny。

---

## 注意事项

*（项目特有的测试注意事项）*
