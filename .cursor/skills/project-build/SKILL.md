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

---

## 环境要求

### Node.js
- **状态**：✅ 已验证
- **版本**：v20.16.0（经 nvm 管理）
- **路径**：`/home/chendc/.nvm/versions/node/v20.16.0/bin/node`
- **用途**：仅供 Playwright MCP server（`npx -y @playwright/mcp@latest`）使用。**hook 与测试脚本均不依赖 Node.js**（纯 bash + jq）。
- **依赖**：`jq` 是 hook 与测试脚本的硬依赖，缺失会导致门禁解析失败（fail-closed → deny，不会静默放行）
- **最后验证**：2026-09-15

<!-- 特殊环境变量、工具版本等，同样标注验证状态 -->

---

## 常见问题与解决方案

<!-- 遇到编译错误并解决后记录，标注问题现象 + 解决方案 + 验证状态 -->

*（尚无记录的构建问题）*

---

## 注意事项

### Cursor 侧 hooks —— 无需构建（当前有效）
- **状态**：✅ 已验证（2026-09-15）
- **说明**：`.cursor/hooks/*.sh` 与 `.cursor/hooks/lib/*.sh` 均为 POSIX-ish bash 脚本，由 Cursor 直接执行，无编译步骤。
- **改完必须做的事**：`chmod +x <脚本>`，否则 hook 不执行；然后跑 `tools/` 下的行为测试。
- **回归命令**：
  ```bash
  for t in tools/test-*.sh; do bash "$t"; done
  ```
- **可移植性约束（踩过坑）**：禁止 `grep -P`；禁止 `stat -c %Y`（用 `stat --version` 探测后回退 `stat -f %m`）；多字节字符前的变量必须写 `"${var}"` 而非 `"$var"`（bash 3.2 会吞字符 → `set -u` 下 exit 1 → 门禁 fail open）。

