#!/bin/bash
# ============================================
# context-snapshot.sh — 状态快照 (Trae 版)
# 绑定: Stop（与 pipeline-advance.sh 一同在 Stop 事件触发）
# 作用: 每次 Agent 停止时更新状态快照，确保后续 SessionStart 可恢复
# 注: Trae 无 preCompact 事件，改为在 Stop 时持续写入快照
# ============================================

INPUT=$(cat 2>/dev/null || echo '{}')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 检查是否有活跃工作流
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    exit 0
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
SPEC_DIR=".specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"

if [ ! -f "$STATUS_FILE" ]; then
    exit 0
fi

# 记录快照日志（追加）
mkdir -p "$SPEC_DIR"
cat >> "$SPEC_DIR/snapshot-log.jsonl" <<EOF
{"timestamp":"$TIMESTAMP","hook":"Stop","slug":"$SLUG"}
EOF

# 解析当前状态，写恢复指南
CURRENT_STAGE=$(jq -r '.current_stage // "unknown"' "$STATUS_FILE" 2>/dev/null)
HG1=$(jq -r '.hg1 // "pending"' "$STATUS_FILE" 2>/dev/null)
HG2=$(jq -r '.hg2 // "pending"' "$STATUS_FILE" 2>/dev/null)
HG3=$(jq -r '.hg3 // "pending"' "$STATUS_FILE" 2>/dev/null)
CURRENT_PHASE=$(jq -r '.current_phase // ""' "$STATUS_FILE" 2>/dev/null)
LOOP_COUNT=$(jq -r '.loop_count // 0' "$STATUS_FILE" 2>/dev/null)

cat > "$SPEC_DIR/recovery-instructions.md" <<RECOVERY
# 会话恢复指南 — $TIMESTAMP

## 恢复步骤（按序执行）
1. 读取 \`.specdev/active-workflow\` → slug: $SLUG
2. 读取 \`.specdev/specs/$SLUG/current-status.json\` → 确认当前状态
3. 检查 Human Gate 状态
4. 向用户报告当前状态，等待确认后继续

## 当前状态快照
- **工作流**: $SLUG
- **阶段**: $CURRENT_STAGE
- **当前 Phase**: ${CURRENT_PHASE:-无}
- **HG-1**: $HG1
- **HG-2**: $HG2
- **HG-3**: $HG3
- **循环次数**: $LOOP_COUNT
- **快照时间**: $TIMESTAMP
RECOVERY

exit 0
