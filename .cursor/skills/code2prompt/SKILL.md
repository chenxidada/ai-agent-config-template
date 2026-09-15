---
name: code2prompt
description: >-
  Generate structured codebase file index for LLM analysis. Use when: exploring
  a new codebase, analyzing repository structure, or preparing code context for
  an agent. Trigger words: code2prompt, repo map, codebase index, file inventory.
---

## code2prompt

### 安装

```bash
cargo install code2prompt
```

### 用法（code-explorer 使用）

```bash
# 生成结构化文件索引
code2prompt src/ \
  --include="*.cpp,*.h,*.hpp" \
  --exclude="tests/*,third_party/*,build/*" \
  --output-file .specdev/specs/<slug>/phases/<phase-id>/repo-map.md

# 如果项目根有 .git，code2prompt 自动尊重 .gitignore
```

### 模板位置

本模板**不随附 `.hbs` 模板**，使用 code2prompt 的默认输出格式即可。
若项目确实需要自定义模板，放在项目自己的 `templates/` 下并在此处记录路径。

### 输出说明

生成的 repo-map.md 包含：
- 源码树（目录结构）
- 文件清单（路径、语言、token 数）
- Git 状态

code-explorer 用这份清单决定「哪些文件值得重点读」，然后用 read 工具逐个读取文件内容进行分析，
最终产出 `.specdev/specs/<slug>/phases/<phase-id>/repo-exploration.md`。
