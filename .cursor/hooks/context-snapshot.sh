#!/bin/bash
# ============================================
# context-snapshot.sh — 上下文压缩前快照
# 绑定: preCompact
# 作用: 记录压缩时间戳 + 写恢复指南
# ============================================

INPUT=$(cat 2>/dev/null || echo '{}')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 记录压缩日志
mkdir -p specs
cat >> specs/compaction-log.jsonl <<EOF
{"timestamp":"$TIMESTAMP","hook":"preCompact"}
EOF

# 如果 current-status.md 存在，写恢复指南
if [ -f specs/current-status.md ]; then
    CURRENT_STAGE=$(grep -oP '当前阶段.*?\*\*\s*\K[^<*]+' specs/current-status.md 2>/dev/null | head -1 | tr -d ' ')
    HG1=$(grep -oP 'HG-1[^|]*\|\s*\K[✅⏳]' specs/current-status.md 2>/dev/null | head -1 | tr -d ' ')
    HG2=$(grep -oP 'HG-2[^|]*\|\s*\K[✅⏳]' specs/current-status.md 2>/dev/null | head -1 | tr -d ' ')
    HG3=$(grep -oP 'HG-3[^|]*\|\s*\K[✅⏳]' specs/current-status.md 2>/dev/null | head -1 | tr -d ' ')

    cat > specs/recovery-instructions.md <<RECOVERY
# 上下文压缩恢复指南 — $TIMESTAMP

上下文已于 $TIMESTAMP 被压缩。

## 恢复步骤（按序执行）
1. 读取 \`specs/current-status.md\` → 确认当前阶段
2. 检查 Human Gate 状态（HG-1:$HG1 HG-2:$HG2 HG-3:$HG3）
3. 读取最后完成的 spec 输出文件
4. 向用户报告当前状态，等待确认后继续

## 当前状态
- **阶段**: ${CURRENT_STAGE:-unknown}
- **HG-1**: ${HG1:-unknown}
- **HG-2**: ${HG2:-unknown}
- **HG-3**: ${HG3:-unknown}
RECOVERY

fi

# preCompact 是 observation-only hook，不能阻止压缩
echo '{}'
exit 0
