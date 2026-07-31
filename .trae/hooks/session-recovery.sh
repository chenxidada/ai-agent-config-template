#!/bin/bash
# ============================================
# session-recovery.sh — 会话启动时恢复状态 (Trae 版)
# 绑定: SessionStart
# 作用: 替代原 preCompact 恢复机制
#       在每次新会话开始时检测活跃工作流并注入恢复上下文
# 协议: stdout 文本注入给 Agent 作为初始上下文
# ============================================

# ── source 共享状态读取片段（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/status-read.sh
source "$HOOK_DIR/lib/status-read.sh"

# ── 初始化心跳时间戳（新会话开始） ──
date +%s > /tmp/.trae-pipeline-heartbeat 2>/dev/null || true

# 检查是否有活跃工作流
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    # 无活跃工作流，不注入额外上下文（保持静默，AC-F4 边界）
    exit 0
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
SPEC_DIR=".specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"
RECOVERY_FILE="$SPEC_DIR/recovery-instructions.md"

if [ ! -f "$STATUS_FILE" ]; then
    # STATUS_FILE 不存在，保持静默（AC-F4 边界：仅在文件存在但损坏时才报错）
    exit 0
fi

# ── 通过共享片段读取状态（fail-loud）──
# 文件存在但损坏/缺字段 → 明确报错，绝不注入伪造的全 pending 状态表（AC-F4）
if ! read_status "$STATUS_FILE" 2>/tmp/.trae-status-read.err; then
    echo "⚠️ **状态文件读取失败** — 无法注入可信恢复上下文"
    echo ""
    echo "\`\`\`"
    cat /tmp/.trae-status-read.err 2>/dev/null
    echo "\`\`\`"
    echo ""
    echo "**请人工检查 \`$STATUS_FILE\` 是否损坏或缺失关键字段（.human_gates / .current_stage），修复后重新开始会话。**"
    echo "（未注入状态表，以避免伪造的全 pending 状态污染恢复流程。）"
    exit 0
fi

# 注入恢复上下文给 Agent
cat <<MSG
📌 **活跃工作流检测到** — 自动恢复上下文

| 字段 | 值 |
|------|-----|
| 工作流 | $SLUG |
| 描述 | $DESCRIPTION |
| 当前阶段 | $CURRENT_STAGE |
| 当前 Phase | ${CURRENT_PHASE:-无} |
| HG-1（需求） | $HG1 |
| HG-2（方案） | $HG2 |
| HG-3（验收） | $HG3 |
| 循环次数 | $LOOP_COUNT |

**请先读取 \`$STATUS_FILE\` 确认完整状态后再继续操作。**
如用户未要求特定操作，请向用户简要报告当前进度并等待指示。
MSG

exit 0
