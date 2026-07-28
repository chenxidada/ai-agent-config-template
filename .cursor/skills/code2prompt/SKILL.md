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

### 用法（repo-explorer 使用）

```bash
# 生成结构化文件索引
code2prompt src/ \
  --include="*.cpp,*.h,*.hpp" \
  --exclude="tests/*,third_party/*,build/*" \
  --template .opencode/templates/repo-map.hbs \
  --output-file specs/phases/<phase-id>/repo-map.md

# 如果项目根有 .git，code2prompt 自动尊重 .gitignore
```

### 模板位置

`.opencode/templates/repo-map.hbs`

### 输出说明

生成的 repo-map.md 包含：
- 源码树（目录结构）
- 文件清单（路径、语言、token 数）
- Git 状态

repo-explorer 用这份清单决定「哪些文件值得重点读」，然后用 read 工具逐个读取文件内容进行分析。
