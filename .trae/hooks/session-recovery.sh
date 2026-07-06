#!/bin/bash
# ============================================
# session-recovery.sh — 会话启动时恢复状态 (Trae 版)
# 绑定: SessionStart
# 作用: 替代原 preCompact 恢复机制
#       在每次新会话开始时检测活跃工作流并注入恢复上下文
# 协议: stdout 文本注入给 Agent 作为初始上下文
# ============================================

# 检查是否有活跃工作流
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    # 无活跃工作流，不注入额外上下文
    exit 0
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
SPEC_DIR=".specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"
RECOVERY_FILE="$SPEC_DIR/recovery-instructions.md"

if [ ! -f "$STATUS_FILE" ]; then
    exit 0
fi

# 解析状态
CURRENT_STAGE=$(jq -r '.current_stage // "unknown"' "$STATUS_FILE" 2>/dev/null)
HG1=$(jq -r '.hg1 // "pending"' "$STATUS_FILE" 2>/dev/null)
HG2=$(jq -r '.hg2 // "pending"' "$STATUS_FILE" 2>/dev/null)
HG3=$(jq -r '.hg3 // "pending"' "$STATUS_FILE" 2>/dev/null)
CURRENT_PHASE=$(jq -r '.current_phase // ""' "$STATUS_FILE" 2>/dev/null)
LOOP_COUNT=$(jq -r '.loop_count // 0' "$STATUS_FILE" 2>/dev/null)
DESCRIPTION=$(jq -r '.description // ""' "$STATUS_FILE" 2>/dev/null)

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
