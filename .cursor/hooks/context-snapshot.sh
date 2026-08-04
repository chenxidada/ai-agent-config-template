#!/bin/bash
# ============================================
# context-snapshot.sh — 上下文压缩前快照 · Cursor 版
# 绑定: preCompact (failClosed:false)
# 作用: 记录压缩时间戳 + 从 current-status.json 写恢复指南
#
# ⚠️ preCompact 是 observation-only hook：无论成功失败，
#    最后必须 echo 合法 JSON（{}）并 exit 0，绝不阻断压缩。
#    （对照 Cursor 官网 https://cursor.com/docs/hooks 的 preCompact 语义）
#
# AC-F1/F2/F4：状态读取收敛到共享 read_status，改读 JSON，
#    损坏/缺字段时 fail-loud（写明确错误提示，不伪造全 pending 恢复指南）。
# ============================================

# ── source 共享状态读取片段（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/status-read.sh
source "$HOOK_DIR/lib/status-read.sh"

INPUT=$(cat 2>/dev/null || echo '{}')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── 检查是否有活跃工作流 ──
# 无 active-workflow → 静默（不写恢复指南），仍 echo {} + exit 0（AC-F4 边界）
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    echo '{}'
    exit 0
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
SPEC_DIR=".specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"

# 状态文件不存在 → 静默（AC-F4 边界），仍 echo {} + exit 0
if [ ! -f "$STATUS_FILE" ]; then
    echo '{}'
    exit 0
fi

# ── 记录压缩日志（追加）──
mkdir -p "$SPEC_DIR"
cat >> "$SPEC_DIR/compaction-log.jsonl" <<EOF
{"timestamp":"$TIMESTAMP","hook":"preCompact","slug":"$SLUG"}
EOF

# ── 通过共享片段读取状态（fail-loud，AC-F4）──
# 文件存在但损坏/缺字段 → 写明确错误提示到 recovery-instructions.md，
# 绝不写出伪造的全 pending 恢复指南。
if ! read_status "$STATUS_FILE" 2>/tmp/.cursor-status-read.err; then
    ERR_MSG=$(cat /tmp/.cursor-status-read.err 2>/dev/null)
    cat > "$SPEC_DIR/recovery-instructions.md" <<RECOVERY
# ⚠️ 上下文压缩恢复指南 — $TIMESTAMP（状态读取失败）

**未能生成正常恢复快照** — \`$STATUS_FILE\` 无法读取或缺失关键字段。
为避免伪造状态污染，本文件不写入任何 Human Gate 状态值。

## 错误详情
\`\`\`
$ERR_MSG
\`\`\`

## 恢复步骤（人工介入）
1. 人工检查 \`$STATUS_FILE\` 是否损坏（JSON 非法）或缺失关键字段（\`.human_gates\` 含 hg1/hg2/hg3、\`.current_stage\`）。
2. 修复后重新读取，确认当前阶段与 Human Gate 状态。
3. 向用户报告，等待确认后再继续。
RECOVERY
    # preCompact 不能阻断压缩：仍输出合法 JSON + exit 0
    echo '{}'
    exit 0
fi

# ── 成功路径：从 JSON 状态写恢复指南 ──
cat > "$SPEC_DIR/recovery-instructions.md" <<RECOVERY
# 上下文压缩恢复指南 — $TIMESTAMP

上下文已于 $TIMESTAMP 被压缩。

## 恢复步骤（按序执行）
1. 读取 \`.specdev/active-workflow\` → slug: $SLUG
2. 读取 \`.specdev/specs/$SLUG/current-status.json\` → 确认当前状态
3. 检查 Human Gate 状态
4. 读取最后完成的 spec 输出文件
5. 向用户报告当前状态，等待确认后继续

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

# preCompact 是 observation-only hook，不能阻止压缩
echo '{}'
exit 0
