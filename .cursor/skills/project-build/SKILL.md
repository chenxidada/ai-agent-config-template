---
name: project-build
description: >-
  Build/compile knowledge: commands, flags, dependency install, environment setup,
  common build errors and solutions. Use when: building, compiling, encountering
  build errors, changing build configuration, or installing dependencies.
  Trigger words: cmake, build, compile, make, ninja, gcc, clang, link, library, dependency.
---

## 项目构建技能

本文件由 implementer agent 在项目开发过程中自动维护，verifier agent 交叉验证。
记录项目特有的构建知识，避免每次重新摸索。

**⚠️ 维护规则**：
- 每条知识有验证状态：✅ 已验证 / ⚠️ 已过期 / ❌ 未验证
- 同一事物的多条记录应合并，而非并列
- 路径已不存在的条目直接删除（留着一个不存在的路径只会误导下游 agent）
- verifier 在验证失败时也应检查并更新构建知识

---

## 构建命令

> **状态说明**：✅=已验证可用 | ⚠️=已过期/不可用 | ❌=未验证

*（尚无已验证的构建命令 — 本仓库不含需要编译的产物）*

---

## 依赖安装

<!-- 格式同上，标注状态 + 环境 + 最后验证时间 -->

*（尚无已验证的依赖安装信息）*

> 若将来决定升级 git（见下方「环境要求 → Git」），需先补装 `gettext` 与 `libcurl4-openssl-dev`
> 才能在 focal 上编译源码；走 PPA 则无需额外依赖。

---

## 环境要求

### Node.js
- **状态**：✅ 已验证
- **版本**：v20.16.0（经 nvm 管理）
- **路径**：`/home/chendc/.nvm/versions/node/v20.16.0/bin/node`
- **用途**：仅供 Playwright MCP server（`npx -y @playwright/mcp@latest`）使用。**hook 与测试脚本均不依赖 Node.js**（纯 bash + jq）。
- **依赖**：`jq` 是 hook 与测试脚本的硬依赖，缺失会导致门禁解析失败（fail-closed → deny，不会静默放行）
- **最后验证**：2026-09-15

### Git —— 本机 2.25.1 < Cursor 注入参数所需版本（根因已定位）
- **状态**：✅ 机制已确认并验证绕过（2026-09-15）
- **本机版本**：`2.25.1`（Ubuntu 20.04 focal 自带；apt 源里最高也只有 2.25.1）
- **现象**：`git commit` 报 `error: unknown option 'trailer'`，而错误信息里**看不到 `--trailer`**
- **根因（已定位到文件）**：Cursor 内置扩展 `cursor-agent-exec` 用 tree-sitter 解析 agent 发出的 shell
  命令，并对其中的 `git commit` **注入** `--trailer "Co-authored-by: Cursor <cursoragent@cursor.com>"`。
  证据：`/usr/share/cursor/resources/app/extensions/cursor-agent-exec/dist/main.js` 内同时含该署名常量
  与 `` --trailer "${...}" `` 模板（Cursor 3.9.16）。而 `--trailer` 需要 **git ≥ 2.32**。
- **诊断方法**：`GIT_TRACE=1 git commit --dry-run -m t`
  → 会打印注入后的真实 argv：`git commit --trailer 'Co-authored-by: Cursor ...' --dry-run -m t`
- **✅ 推荐写法（本仓库既有约定：消息自带署名）**

  ```bash
  git commit -m "$(cat <<'EOF'
  提交信息

  Co-authored-by: Cursor <cursoragent@cursor.com>
  EOF
  )"
  ```

  **原理（实测）**：注入器带一个「已署名则跳过」的短路判断 —— 只要**整条 shell 命令字符串里出现**
  `Co-authored-by: Cursor`（或 `Made-with: Cursor`，或完整署名），就完全不注入。
  于是 argv 保持干净，2.25.1 也能正常提交，**且署名得以保留**。
- **备选写法（不补署名）**：`command git commit ...`（tree-sitter 看到的命令名变成 `command`，匹配不到
  `git commit`），或 `G=git && "$G" commit ...`。两者都能绕过注入，但**不会**自动补署名。
- **实测排除项**：`/tmp/git-commit-allowed` 标记的有无**不影响**注入行为。
- **影响范围**：注入只针对 `git commit`；`push` / `add` / `log` 等正常调用不受影响。
- **为何此前未遇到**：本仓库更早的提交消息里本就带了该署名（如 `6084ab9`、`152d0bd`），触发上述短路
  → 未注入 → 正常提交。**只有提交消息不带署名时才会踩到**（推断，与全部实测一致）。
- **根治方式（未采纳，用户决策）**：升级 git 到 ≥ 2.32。
  - `ppa:git-core/ppa` → 实测该 PPA 对 focal 提供 **2.50.1**，约 1 分钟；代价是添加第三方 apt 源。
  - 源码编译 → 自包含，需先装 `gettext` + `libcurl4-openssl-dev`，约 5-10 分钟。
  - **决策记录**：2026-09-15 用户选择**不升级系统**，保持绕过写法。
- **最后验证**：2026-09-15（三种写法均已用 `GIT_TRACE` 实测 argv）

<!-- 特殊环境变量、工具版本等，同样标注验证状态 -->

---

## 常见问题与解决方案

### `error: unknown option 'trailer'` 出现在 `git commit` 上
- **现象**：提交时报该错，且错误信息里**完全没有 `--trailer`**（参数由 Cursor 在外部注入，肉眼看不到）
- **根因**：Cursor 的 `cursor-agent-exec` 扩展注入 `--trailer`，但本机 git < 2.32
- **解决**：在提交消息里带上 `Co-authored-by: Cursor <cursoragent@cursor.com>`（注入器会跳过）；
  或退而求其次用 `command git commit ...`（详见「环境要求 → Git」）
- **验证状态**：✅ 已验证

---

## 注意事项

### Cursor 侧 hooks —— 无需构建（当前有效）
- **状态**：✅ 已验证（2026-09-15）
- **说明**：`.cursor/hooks/*.sh` 与 `.cursor/hooks/lib/*.sh` 均为 POSIX-ish bash 脚本，由 Cursor 直接执行，无编译步骤。
- **改完必须做的事**：`chmod +x <脚本>`，否则 hook 不执行；然后跑 `tools/` 下的行为测试。
  - ⚠️ **这条已真实踩过**：`drift-reminder.sh` 因缺可执行位从创建起一直没生效，而 133 项测试全绿 —— 因为测试都用 `bash <脚本>` 调用，不依赖可执行位。现已由 `test-hook-contract.sh` 断言 `-x` 兜底。
- **回归命令**：
  ```bash
  for t in tools/test-*.sh; do bash "$t"; done
  ```
- **可移植性约束（踩过坑）**：禁止 `grep -P`；禁止 `stat -c %Y`（用 `stat --version` 探测后回退 `stat -f %m`）；多字节字符前的变量必须写 `"${var}"` 而非 `"$var"`（bash 3.2 会吞字符 → `set -u` 下 exit 1 → 门禁 fail open）。
- **测试盲区教训**：被测对象的**调用方式**必须与生产环境一致。用 `bash x.sh` 测一个由 Cursor 直接执行的 hook，就测不到执行位、shebang、CRLF 等「启动层」问题。

