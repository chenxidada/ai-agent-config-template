#!/bin/bash
# ============================================
# context-snapshot.sh — 状态快照 (Trae 版)
# 绑定: Stop（与 pipeline-advance.sh 一同在 Stop 事件触发）
# 作用: 每次 Agent 停止时更新状态快照，确保后续 SessionStart 可恢复
# 注: Trae 无 preCompact 事件，改为在 Stop 时持续写入快照
# ============================================

# ── source 共享状态读取片段（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/status-read.sh
source "$HOOK_DIR/lib/status-read.sh"

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
    # STATUS_FILE 不存在，保持静默（AC-F4 边界）
    exit 0
fi

# 记录快照日志（追加）
mkdir -p "$SPEC_DIR"
cat >> "$SPEC_DIR/snapshot-log.jsonl" <<EOF
{"timestamp":"$TIMESTAMP","hook":"Stop","slug":"$SLUG"}
EOF

# ── 通过共享片段读取状态（fail-loud）──
# 文件存在但损坏/缺字段 → 明确报错，绝不写出伪造的全 pending recovery-instructions.md（AC-F4）
if ! read_status "$STATUS_FILE" 2>/tmp/.trae-status-read.err; then
    echo "⚠️ **状态文件读取失败** — 未更新 recovery-instructions.md（避免伪造状态污染）"
    echo ""
    echo "\`\`\`"
    cat /tmp/.trae-status-read.err 2>/dev/null
    echo "\`\`\`"
    echo ""
    echo "**请人工检查 \`$STATUS_FILE\` 是否损坏或缺失关键字段（.human_gates / .current_stage）。**"
    exit 0
fi

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

# ── Phase 1 Core A：向 recovery-instructions.md 追加同一锚定块 ──
# 与 session-recovery.sh 的 SessionStart 注入逐字一致（共享 emit_anchoring_block）。
emit_anchoring_block "$CURRENT_STAGE" >> "$SPEC_DIR/recovery-instructions.md"

exit 0
