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
- ✅ **pipeline-advance.sh 情况 D 矩阵分流集成 dry-run**（2026-08-24 verified，Phase 4）：
  ```bash
  bash .specdev/specs/pipeline-verification-hardening/phases/phase-4-class-e-verifier-loopback/test-scripts/integration-advance-dryrun.sh
  ```
  覆盖 VP-4/5/6/7/12/E7/E8：FAIL/PARTIAL+CRITICAL→回 implementer；PARTIAL+MEDIUM→ask 语义；PARTIAL(LOW)/PASS→HG-3；VLC=2→escalation；PASS 提示含 verifier_loop_count 重置；gate/advance/lib 三方解析对拍一致。
- ✅ **verifier 独立验证脚本（自建 fixture，不复用 implementer 断言）**（2026-08-24 verified，Phase 4）：
  ```bash
  bash .specdev/specs/pipeline-verification-hardening/phases/phase-4-class-e-verifier-loopback/test-scripts/verifier-independent-check.sh
  ```
  26 断言全过。额外覆盖 implementer/reviewer 未测边界：VLC=1(loop) vs VLC=2(escalate) 临界（`>=2` 而非 `>2`）、`verifier_loop_count` 字段缺失时 `// 0` 兜底、PARTIAL 残余区无严重性标记(NONE)→hg3、多值枚举判决行 unparseable→hg3 兜底、PARTIAL+CRITICAL 三方对拍（reviewer 建议补齐）。
- ✅ **pipeline-gate.sh AC-E9 verifier_loop_count 硬阻断 dry-run**（2026-08-24 verified，Phase 4 GAP-1 补丁）：
  ```bash
  bash .specdev/specs/pipeline-verification-hardening/phases/phase-4-class-e-verifier-loopback/test-scripts/gap1-gate-vlc-check.sh
  ```
  10 断言全过。覆盖：VLC=2/3 + 推进动作(切 current_phase / hg3=passed)→deny(exit 2)；VLC=0/1/缺失→放行；content 缺字段回退磁盘 status 读取；VLC=2 但非推进(仅更新计数)→不误 deny；回归 loop_count>=2 仍 deny + Class C PASS+MEDIUM 仍 ask（AC-E9 与既有校验隔离共存）。

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
- ✅ **advance.sh 是 Stop hook，没有 ask/deny 协议，只输出引导文本**（2026-08-24，Phase 4）。它从 stdin JSON 取 `cwd`，再从磁盘读 `.specdev/active-workflow`→slug→`current-status.json`（`read_status` + `jq '.verifier_loop_count // 0'`）+ `phases/<phase>/verification.md`（`parse_verdict`/`max_residual_severity`）。dry-run 判定改为 grep stdout 关键子串（如「自动回 implementer」「需用户抉择」「Human Gate 3」「已达上限」）+ 断言 exit 0。构造沙盒要让 `CURRENT_STAGE=phase-implementation` + `CURRENT_PHASE` 设置 + verification.md 存在 + hg3=pending，并且 `reviewer=completed`（跳情况 A）、不建 `review-*.md`（TOTAL=0 跳情况 B）才能落到情况 D。
- ✅ **VP-E8 解析一致性对拍**（2026-08-24，Phase 4）：advance.sh 与 gate.sh 必须 source 同一份 `verdict-parse.sh`（结构层 grep 校验，杜绝第二份解析）；再用「直接 source lib 计算 ground-truth」对拍 gate 的 ask/allow 与 advance 的 loop/ask/hg3 路由，三方由同一 `[判决/严重性]` 派生即为一致。注意对拍 gate 分支时仍需齐备 implementation.md(≥10 行)/review.md(≥5 行,判决非 MUST-FIX)，否则被前置 `check_file_valid` deny 拦截。

---

## 注意事项

*（项目特有的测试注意事项）*
