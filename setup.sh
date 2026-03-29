#!/bin/bash
#
# AI Agent Config - 一键导入脚本
#
# 用法:
#   cd /your/project
#   bash /path/to/ai-agent-config-template/setup.sh
#
# 功能:
#   1. 复制所有 AI Agent 配置文件到当前项目
#   2. 将 opencode.jsonc 加入 .gitignore
#   3. 同步模板中的 .opencode 目录（skills / future configs）
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"

echo "=========================================="
echo "  AI Agent Config 导入工具"
echo "=========================================="
echo ""
echo "  模板目录: $SCRIPT_DIR"
echo "  目标项目: $TARGET_DIR"
echo ""

# ---- 复制配置文件 ----

FILES=("opencode.jsonc" ".mcp.json" "AGENTS.md" ".cursorrules" ".windsurfrules" "knowledge-base-mcp.sh")

for file in "${FILES[@]}"; do
  src="$SCRIPT_DIR/$file"
  dst="$TARGET_DIR/$file"

  if [ ! -f "$src" ]; then
    echo "  [跳过] $file (模板中不存在)"
    continue
  fi

  if [ -f "$dst" ]; then
    read -p "  [冲突] $file 已存在，覆盖? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "  [保留] $file"
      continue
    fi
  fi

  cp "$src" "$dst"
  echo "  [完成] $file"
done

echo ""

# ---- 同步 .opencode 模板目录 ----

OPENCODE_SRC="$SCRIPT_DIR/.opencode"
OPENCODE_DST="$TARGET_DIR/.opencode"

if [ -d "$OPENCODE_SRC" ]; then
  if [ -d "$OPENCODE_DST" ]; then
    read -p "  [冲突] .opencode 已存在，合并模板内容并覆盖同名文件? (y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      mkdir -p "$OPENCODE_DST"
      cp -R "$OPENCODE_SRC"/. "$OPENCODE_DST"/
      echo "  [完成] .opencode (已合并模板内容)"
    else
      echo "  [保留] .opencode"
    fi
  else
    cp -R "$OPENCODE_SRC" "$OPENCODE_DST"
    echo "  [完成] .opencode"
  fi
fi

echo ""

# ---- 添加 .gitignore 条目 ----

GITIGNORE="$TARGET_DIR/.gitignore"
ENTRIES=("opencode.jsonc")

if [ -f "$GITIGNORE" ]; then
  for entry in "${ENTRIES[@]}"; do
    if ! grep -qF "$entry" "$GITIGNORE"; then
      echo "$entry" >> "$GITIGNORE"
      echo "  [gitignore] 已添加 $entry"
    else
      echo "  [gitignore] $entry 已存在"
    fi
  done
else
  read -p "  .gitignore 不存在，是否创建? (Y/n): " confirm
  if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
    printf "%s\n" "${ENTRIES[@]}" > "$GITIGNORE"
    echo "  [gitignore] 已创建，包含: ${ENTRIES[*]}"
  fi
fi

echo ""
echo "=========================================="
echo "  导入完成!"
echo ""
echo "  如需显式设置环境变量:"
echo "    export KNOWNBASE_ROOT=/path/to/knownbase/AI-Chat"
echo "    export KB_API_URL=http://localhost:4000/api/v1"
echo ""
echo "  启动脚本会尝试这些候选路径:"
echo "    \$HOME/workspace/code/knownbase/AI-Chat"
echo "    \$HOME/code/knownbase/AI-Chat"
echo "    \$PWD/../knownbase/AI-Chat"
echo "    \$PWD/knownbase/AI-Chat"
echo ""
echo "  各工具使用方式:"
echo "    OpenCode  → 直接启动 opencode，自动读取 opencode.jsonc"
echo "    Cursor    → 打开项目，Settings > MCP 确认 knowledge-base Running"
echo "    Claude    → 自动读取 .mcp.json 和 AGENTS.md"
echo "    Windsurf  → 自动读取 .mcp.json 和 .windsurfrules"
echo "=========================================="
