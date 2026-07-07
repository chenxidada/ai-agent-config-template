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
  --template .trae/templates/repo-map.hbs \
  --output-file .specdev/specs/<slug>/phases/<phase-id>/repo-map.md

# 如果项目根有 .git，code2prompt 自动尊重 .gitignore
```

### 模板位置

`.trae/templates/repo-map.hbs`（如不存在，code2prompt 使用内置默认模板）

### 输出说明

生成的 repo-map.md 包含：
- 源码树（目录结构）
- 文件清单（路径、语言、token 数）
- Git 状态

code-explorer 用这份清单决定「哪些文件值得重点读」，然后逐个读取文件内容进行分析。
