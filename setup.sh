#!/bin/bash
#
# AI Agent Config - 一键导入脚本
#
# 用法:
#   cd /your/project
#   bash /path/to/ai-agent-config-template/setup.sh [--cursor|--opencode|--all]
#
# 选项:
#   --cursor    仅安装 Cursor 配置（.cursor/ + .cursorrules + .mcp.json + AGENTS.md）
#   --opencode  仅安装 OpenCode 配置（.opencode/ + opencode.jsonc）
#   --all       安装全部配置（默认）
#   --force     跳过冲突确认，直接覆盖
#
# 功能:
#   1. 复制 AI Agent 配置文件到当前项目
#   2. 同步模板目录（.cursor/ / .opencode/）
#   3. 将 opencode.jsonc 加入 .gitignore
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"

MODE="all"
FORCE=false

# ---- 解析参数 ----
for arg in "$@"; do
    case "$arg" in
        --cursor)   MODE="cursor" ;;
        --opencode) MODE="opencode" ;;
        --all)      MODE="all" ;;
        --force)    FORCE=true ;;
        -h|--help)
            echo "用法: bash setup.sh [--cursor|--opencode|--all] [--force]"
            exit 0
            ;;
    esac
done

echo "=========================================="
echo "  AI Agent Config 导入工具"
echo "=========================================="
echo ""
echo "  模板目录: $SCRIPT_DIR"
echo "  目标项目: $TARGET_DIR"
echo "  安装模式: $MODE"
[[ "$FORCE" == "true" ]] && echo "  覆盖模式: 强制覆盖"
echo ""

# ---- 通用文件复制函数 ----
copy_file() {
    local src="$1"
    local dst="$2"
    local label="${3:-$(basename "$dst")}"

    if [ ! -f "$src" ]; then
        echo "  [跳过] $label (模板中不存在)"
        return 1
    fi

    if [ -f "$dst" ] && [ "$FORCE" != "true" ]; then
        read -p "  [冲突] $label 已存在，覆盖? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "  [保留] $label"
            return 1
        fi
    fi

    cp "$src" "$dst"
    echo "  [完成] $label"
    return 0
}

copy_dir() {
    local src="$1"
    local dst="$2"
    local label="${3:-$(basename "$dst")}"

    if [ ! -d "$src" ]; then
        echo "  [跳过] $label (模板中不存在)"
        return 1
    fi

    if [ -d "$dst" ] && [ "$FORCE" != "true" ]; then
        read -p "  [冲突] $label 已存在，合并模板内容并覆盖同名文件? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "  [保留] $label"
            return 1
        fi
    fi

    mkdir -p "$dst"
    cp -R "$src"/. "$dst"/
    echo "  [完成] $label (已合并模板内容)"
    return 0
}

# ============================================
# Cursor 配置安装
# ============================================
install_cursor() {
    echo "--- Cursor 配置 ---"
    echo ""

    # 通用文件
    CURSOR_FILES=(".mcp.json" "AGENTS.md" ".cursorrules" "knowledge-base-mcp.sh")
    for file in "${CURSOR_FILES[@]}"; do
        copy_file "$SCRIPT_DIR/$file" "$TARGET_DIR/$file"
    done

    # .cursor/ 目录（规则 + 子Agent + 命令 + 钩子 + 插件清单）
    copy_dir "$SCRIPT_DIR/.cursor" "$TARGET_DIR/.cursor" ".cursor/ (规则+子Agent+命令+钩子)"

    # 技能目录（Cursor 自动发现 SKILL.md）
    if [ -d "$SCRIPT_DIR/.opencode/skills" ]; then
        copy_dir "$SCRIPT_DIR/.opencode/skills" "$TARGET_DIR/.cursor/skills" ".cursor/skills/"
    fi

    echo ""
    echo "  ✅ Cursor 配置导入完成"
    echo ""
    echo "  在 Cursor 中的使用方式:"
    echo "    1. 打开项目 -> 侧边栏「自定义」"
    echo "    2. 确认知识库 MCP: knowledge-base → Running"
    echo "    3. 确认 Playwright MCP: playwright → Running"
    echo "    4. 子 Agent 已自动注册，Orchestrator 通过 Task 工具调度"
    echo "    5. 命令已注册: /feature /bugfix /rebuild /idea /analyze"
    echo ""
}

# ============================================
# OpenCode 配置安装
# ============================================
install_opencode() {
    echo "--- OpenCode 配置 ---"
    echo ""

    # opencode.jsonc
    copy_file "$SCRIPT_DIR/opencode.jsonc" "$TARGET_DIR/opencode.jsonc"

    # .opencode/ 目录
    copy_dir "$SCRIPT_DIR/.opencode" "$TARGET_DIR/.opencode" ".opencode/"

    echo ""
    echo "  ✅ OpenCode 配置导入完成"
    echo ""
    echo "  OpenCode 使用方式:"
    echo "    直接启动 opencode，自动读取 opencode.jsonc"
    echo ""

    # ---- .gitignore ----
    GITIGNORE="$TARGET_DIR/.gitignore"
    ENTRY="opencode.jsonc"

    if [ -f "$GITIGNORE" ]; then
        if ! grep -qF "$ENTRY" "$GITIGNORE"; then
            echo "$ENTRY" >> "$GITIGNORE"
            echo "  [gitignore] 已添加 $ENTRY"
        else
            echo "  [gitignore] $ENTRY 已存在"
        fi
    else
        if [ "$FORCE" != "true" ]; then
            read -p "  .gitignore 不存在，是否创建? (Y/n): " confirm
            if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
                return
            fi
        fi
        echo "$ENTRY" > "$GITIGNORE"
        echo "  [gitignore] 已创建，包含: $ENTRY"
    fi
    echo ""
}

# ============================================
# 主逻辑
# ============================================

case "$MODE" in
    cursor)
        install_cursor
        ;;
    opencode)
        install_opencode
        ;;
    all)
        echo "--- 全部配置 ---"
        echo ""
        install_cursor
        echo ""
        install_opencode
        ;;
esac

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
echo "    Cursor    → 打开项目，自定义页面查看规则/子Agent/命令/钩子"
echo "    OpenCode  → 直接启动 opencode，自动读取 opencode.jsonc"
echo "    Claude    → 自动读取 .mcp.json 和 AGENTS.md"
echo "    Windsurf  → 自动读取 .mcp.json 和 .windsurfrules"
echo "=========================================="
