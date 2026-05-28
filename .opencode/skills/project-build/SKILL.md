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

<!-- 格式示例：
### `npm run build`
- **状态**：✅ 已验证
- **环境**：Node 22 / npm 10
- **说明**：等同于 tsc -p tsconfig.build.json && node scripts/postbuild.js
- **最后验证**：2026-05-26 by implementer，Phase 2 构建成功

### `npx tsc --build`
- **状态**：⚠️ 已过期（缺少 postbuild 步骤，改用 npm run build）
- **过期标记**：2026-05-26
-->

*（尚无已验证的构建命令 — implementer 首次成功编译后填写）*

---

## 依赖安装

<!-- 格式同上，标注状态 + 环境 + 最后验证时间 -->

*（尚无已验证的依赖安装信息）*

---

## 环境要求

<!-- 特殊环境变量、工具版本等，同样标注验证状态 -->

*（尚无已验证的环境信息）*

---

## 常见问题与解决方案

<!-- 遇到编译错误并解决后记录，标注问题现象 + 解决方案 + 验证状态 -->

*（尚无记录的构建问题）*

---

## 注意事项

*（尚无特殊注意点）*
