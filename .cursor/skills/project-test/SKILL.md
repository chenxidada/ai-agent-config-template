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
- 同一事物的多条记录应合并，而非并列
- 路径已不存在的条目直接删除（留着一个不存在的路径只会误导下游 agent）
- implementer 在运行测试时也应检查并更新测试知识

---

## 测试框架

> **状态说明**：✅=已验证可用 | ⚠️=已过期/不可用 | ❌=未验证

### Hook 行为测试（当前唯一测试体系）
- **状态**：✅ 已验证（2026-09-15）
- **框架**：无框架依赖，纯 bash + `jq`，每个脚本自带 mock payload 与断言计数
- **测试对象**：`.cursor/hooks/` 下的 shell hook 与 `lib/` 共享库
- **测试风格**：行为断言（构造模拟 payload → 调 hook → 断言 stdout JSON 的 `permission` / `additional_context` 字段），**不是**单元测试
- **分布**：

| 脚本 | 覆盖对象 | 断言数 |
|------|---------|:--:|
| `tools/test-gate.sh` | `pipeline-gate.sh` 的 allow/deny 分支（HG 状态、DAG 校验、分支校验、技术债登记） | 41 |
| `tools/test-hook-contract.sh` | 事件 × 输出字段契约（防字段名写错导致静默失效）+ 文档一致性 | 27 |
| `tools/test-shell-guard.sh` | `shell-guard.sh` 危险命令守卫 + 逃生舱 | 22 |
| `tools/test-drift.sh` | `drift-reminder.sh` 漂移检测（D1/D2/D3）与防刷屏 | 22 |
| `tools/test-verdict.sh` | `lib/verdict-parse.sh` 判决解析（单值 + 证据计数） | 21 |
| **合计** | | **133** |

- **最后验证**：2026-09-15 by verifier，133/133 passed

---

## 运行命令

### 全部测试（回归必跑）

```bash
for t in tools/test-*.sh; do bash "$t"; done
```

- **状态**：✅ 已验证
- **环境**：Linux / macOS，需 `bash` 与 `jq`
- **输出**：每个脚本末尾打印 `结果：N 通过 / M 失败`
- **退出码**：0（全部通过）/ 1（有失败）
- **预期总量**：133 通过 / 0 失败
- **最后验证**：2026-09-15

### 单个套件

```bash
bash tools/test-gate.sh           # 门禁行为（改动 pipeline-gate.sh 后必跑）
bash tools/test-verdict.sh        # 判决解析（改动 review.md 解析逻辑后必跑）
bash tools/test-shell-guard.sh    # 命令守卫
bash tools/test-hook-contract.sh  # 输出字段契约 + 文档一致性（改动任何 hook 输出后必跑）
bash tools/test-drift.sh          # 漂移提醒
```

### 语法检查（改 hook 脚本后的最快反馈）

```bash
bash -n .cursor/hooks/pipeline-gate.sh
bash -n .cursor/hooks/shell-guard.sh
```

### Git 合规检查

```bash
git branch --show-current          # 必须处于 impl-<phase-id> 分支
git diff --name-only main..HEAD    # 改动清单
git status --short                 # 提交前必须展示给用户
```

- **状态**：✅ 已验证
- **说明**：验证 Phase 是否在 `impl-*` 分支上工作（`pipeline-gate.sh` 也会在派发 implementer 时程序化校验）

### 全仓文本一致性检查

```bash
rg -n '<旧名称|旧路径>' --glob '!.git' .    # 查残留引用
for f in $(rg -l '' --glob '*.json' --glob '!.git'); do jq empty "$f"; done   # 所有 JSON 必须合法
```

- **状态**：✅ 已验证（2026-09-15 全仓残留引用清理时使用）

---

## 测试环境配置

- 测试脚本在仓库根目录执行；脚本内部自行 `cd "$(dirname "$0")/.."` 定位根目录并 source `.cursor/hooks/lib/*.sh`
- mock payload 以 heredoc / `printf` 内联构造，不落地临时文件
- 需要隔离文件系统状态的用例（如 `pipeline-gate.sh` 写 `current-status.json`）使用 `mktemp -d` 并在退出时清理
- **无网络依赖**、**无 Node.js 依赖**：全部为 bash + jq

---

## 覆盖率工具

*（尚无覆盖率配置 —— 行为断层测试的覆盖以断言数 + 分支清单人工核对为准）*

---

## 常见问题与解决方案

### hook 改完测试没变化 / 行为没生效
- **现象**：改了 hook 脚本，跑测试仍全绿或行为未变
- **根因**：脚本没有执行权限，Cursor 静默跳过
- **解决**：`chmod +x .cursor/hooks/*.sh .cursor/hooks/lib/*.sh`
- **验证状态**：✅ 已验证

### 测试在 macOS 上失败但在 Linux 上通过
- **根因**：用了 GNU 扩展。`grep -P`（PCRE）和 `stat -c %Y` 在 BSD 上直接失败
- **解决**：一律用 `grep -E` / `sed` / `awk`；取文件时间用 `stat --version` 探测后回退 `stat -f %m`
- **验证状态**：✅ 已验证

### `set -u` 下脚本莫名 exit 1
- **根因**：多字节字符紧跟变量未加花括号，bash 3.2 会把多字节字符吞进变量名 → `unbound variable`
- **解决**：写 `"${var}）"` 而非 `"$var）"`
- **验证状态**：✅ 已验证

---

## 注意事项

- 测试脚本自己是「行为契约」：**改 hook 的行为前先改断言，再改实现**
- `test-hook-contract.sh` 同时守卫文档一致性 —— 改 hook 的 `additional_context` 文案后要同步它
- 断言数是公开承诺（README / AGENTS.md / CHANGELOG 都引用 133），新增断言时需同步更新这三处
- 全部测试跑一次约 25 秒（`test-gate.sh` 占大头，因其反复 fork jq）
