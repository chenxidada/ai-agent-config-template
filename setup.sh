#!/bin/bash
#
# AI Agent Config - 一键导入脚本
#
# 用法:
#   cd /your/project
#   bash /path/to/ai-agent-config-template/setup.sh [--cursor|--trae|--all]
#
# 选项:
#   --cursor    仅安装 Cursor 配置（.cursor/ + .cursorrules + .mcp.json + AGENTS.md）
#   --trae      仅安装 Trae 配置（.trae/ + .mcp.json + AGENTS.md）
#   --all       安装全部配置（默认）
#   --force     跳过冲突确认，直接覆盖
#
# 功能:
#   1. 复制 AI Agent 配置文件到当前项目
#   2. 同步模板目录（.cursor/ / .trae/）
#   3. 复制 .specdev/ 运行时模板
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
        --trae)     MODE="trae" ;;
        --all)      MODE="all" ;;
        --force)    FORCE=true ;;
        --skip-kb-check) SKIP_KB_CHECK=true ;;
        -h|--help)
            echo "用法: bash setup.sh [--cursor|--trae|--all] [--force] [--skip-kb-check]"
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
    # 清理目标中的符号链接，避免 cp -R 无法用目录覆盖符号链接
    find "$dst" -maxdepth 1 -type l -exec rm -f {} \; 2>/dev/null || true
    cp -R "$src"/. "$dst"/
    echo "  [完成] $label (已合并模板内容)"
    return 0
}

# ---- Knownbase 预检 ----
check_knowledge_base() {
    if [ "${SKIP_KB_CHECK:-false}" = "true" ]; then
        echo "  [KB] 跳过检查 (--skip-kb-check)"
        return 0
    fi

    local found_at=""
    local candidates=(
        "$HOME/AI-Chat/packages/mcp-server/dist/index.js"
        "$HOME/workspace/AI-Chat/packages/mcp-server/dist/index.js"
        "$HOME/code/AI-Chat/packages/mcp-server/dist/index.js"
        "$HOME/code/knownbase/AI-Chat/packages/mcp-server/dist/index.js"
    )

    for candidate in "${candidates[@]}"; do
        if [ -f "$candidate" ]; then
            found_at="$(dirname "$(dirname "$(dirname "$(dirname "$candidate")")")")"
            break
        fi
    done

    if [ -n "$found_at" ]; then
        echo "  [KB] ✅ 在 $found_at 检测到 Knownbase"
        return 0
    fi

    # Docker 检测
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "kb-mcp-server"; then
        echo "  [KB] ✅ 检测到 kb-mcp-server Docker 容器"
        return 0
    fi

    echo ""
    echo "  ⚠️  [KB] 未检测到 Knownbase（知识库后端）"
    echo "  ─────────────────────────────────────"
    echo "  知识库 MCP 会随 .mcp.json 一起复制，但需要 Knownbase 后端才能工作。"
    echo ""
    echo "  如果你没有 Knownbase："
    echo "    1. 继续安装，稍后在 .mcp.json 中删除 knowledge-base 条目"
    echo "    2. MCP 启动失败不会影响 Cursor 正常工作"
    echo ""
    echo "  如果你已安装 Knownbase："
    echo "    设置环境变量: export KNOWNBASE_ROOT=/path/to/AI-Chat"
    echo "    或启动 Docker: docker-compose up -d mcp-server"
    echo ""
    read -p "  继续安装? (Y/n): " confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        echo "  已取消安装。"
        exit 1
    fi
    return 1
}

# ============================================
# Cursor 配置安装
# ============================================
install_cursor() {
    echo "--- Cursor 配置 ---"
    echo ""

    # Knownbase 预检
    check_knowledge_base

    # 通用文件
    CURSOR_FILES=(".mcp.json" "AGENTS.md" ".cursorrules" "knowledge-base-mcp.sh")
    for file in "${CURSOR_FILES[@]}"; do
        copy_file "$SCRIPT_DIR/$file" "$TARGET_DIR/$file"
    done

    # .cursor/ 目录（规则 + 子Agent + 命令 + 钩子 + skills + snippets + mcp.json）
    copy_dir "$SCRIPT_DIR/.cursor" "$TARGET_DIR/.cursor" ".cursor/ (规则+子Agent+命令+钩子+skills)"

    # 确保 hook 脚本有执行权限（Cursor 直接执行注册路径，无 x 位会被静默跳过）
    if [ -d "$TARGET_DIR/.cursor/hooks" ]; then
        chmod +x "$TARGET_DIR/.cursor/hooks/"*.sh 2>/dev/null || true
    fi

    # .specdev/ 运行时模板（/feature 初始化工作流时会复制这些模板）
    mkdir -p "$TARGET_DIR/.specdev"
    for tmpl in constitution-template.md tech-debt-registry-template.md ui-spec-template.md; do
        if [ -f "$SCRIPT_DIR/.specdev/$tmpl" ]; then
            copy_file "$SCRIPT_DIR/.specdev/$tmpl" "$TARGET_DIR/.specdev/$tmpl" ".specdev/$tmpl"
        fi
    done

    echo ""
    echo "  ✅ Cursor 配置导入完成"
    echo ""
    echo "  在 Cursor 中的使用方式:"
    echo "    1. 打开项目 -> 侧边栏「自定义」"
    echo "    2. 确认知识库 MCP: knowledge-base → Running"
    echo "    3. 确认 Playwright MCP: playwright → Running（UI 任务的视觉验证依赖它）"
    echo "    4. 子 Agent 已自动注册，调度者通过 Task 工具派发"
    echo "    5. 命令已注册: /feature /bugfix /brief /research /specify /plan /implement /status"
    echo ""
}

# ============================================
# Trae 配置安装
# ============================================
install_trae() {
    echo "--- Trae 配置 ---"
    echo ""

    # Knownbase 预检
    check_knowledge_base

    # 通用文件
    TRAE_FILES=(".mcp.json" "AGENTS.md" "knowledge-base-mcp.sh")
    for file in "${TRAE_FILES[@]}"; do
        copy_file "$SCRIPT_DIR/$file" "$TARGET_DIR/$file"
    done

    # .trae/ 目录（规则 + 子Agent + 命令 + 钩子 + 模板 + 代码片段）
    copy_dir "$SCRIPT_DIR/.trae" "$TARGET_DIR/.trae" ".trae/ (规则+子Agent+命令+钩子)"

    # 确保 hook 脚本有执行权限
    if [ -d "$TARGET_DIR/.trae/hooks" ]; then
        chmod +x "$TARGET_DIR/.trae/hooks/"*.sh 2>/dev/null || true
    fi

    # .specdev/ 运行时目录结构
    mkdir -p "$TARGET_DIR/.specdev"
    for tmpl in constitution-template.md tech-debt-registry-template.md ui-spec-template.md; do
        if [ -f "$SCRIPT_DIR/.specdev/$tmpl" ]; then
            copy_file "$SCRIPT_DIR/.specdev/$tmpl" "$TARGET_DIR/.specdev/$tmpl" ".specdev/$tmpl"
        fi
    done

    echo ""
    echo "  ✅ Trae 配置导入完成"
    echo ""
    echo "  在 Trae 中的使用方式:"
    echo "    1. 打开项目 -> SOLO 模式"
    echo "    2. 确认知识库 MCP: knowledge-base → Running"
    echo "    3. 确认 Playwright MCP: playwright → Running（UI 任务的视觉验证依赖它；不可用会降级为 bash+Playwright 并标记 visual-blocking）"
    echo "    4. Subagent 已注册在 .trae/agents/，SOLO Agent 自动路由"
    echo "    5. Hook 已配置在 .trae/hooks.json（PreToolUse + Stop + SessionStart）"
    echo "    6. 命令已注册: /feature /bugfix /brief /research /specify /plan /implement /status"
    echo ""
}

# ============================================
# 主逻辑
# ============================================

case "$MODE" in
    cursor)
        install_cursor
        ;;
    trae)
        install_trae
        ;;
    all)
        echo "--- 全部配置 ---"
        echo ""
        install_cursor
        echo ""
        install_trae
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
echo "    Trae      → SOLO 模式，Subagent 自动路由，Hook 自动生效"
echo "    Claude    → 自动读取 .mcp.json 和 AGENTS.md"
echo "    Windsurf  → 自动读取 .mcp.json 和 .windsurfrules"
echo "=========================================="
