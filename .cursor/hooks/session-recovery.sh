#!/bin/bash
# ============================================
# session-recovery.sh — 会话启动时恢复状态 · Cursor 版
# 绑定: sessionStart (failClosed:false, timeout:10)
# 作用: 新会话 / 新终端开始时（无需触发压缩）检测活跃工作流，
#       经 P0 共享片段 read_status 读状态，以 JSON 向 stdout 注入恢复状态表。
#
# 协议（对照 Cursor 官网 https://cursor.com/docs/hooks）:
#   - Cursor hook 走 JSON 双向通信：stdin = 事件 JSON，stdout = JSON 响应（与 Trae 纯文本不同）。
#   - sessionStart 用例即「inject context at session start」，无需 matcher。
#   - 退出码语义：exit 2 = deny（阻断会话）；exit 0 = success，用 stdout JSON。
#
# ⚠️ exit 0 铁律：所有路径（静默 / 成功注入 / fail-loud）一律 echo 合法 JSON + exit 0，
#    绝不 exit 2（会阻断会话）。hooks.json 中本条目用 failClosed:false。
#
# 决策 1（双字段注入）：注入字段名收敛到单一 emit_recovery_json 包装：
#    同时输出 Claude-Code 兼容的嵌套形态 hookSpecificOutput.additionalContext
#    并镜像顶层 additionalContext（无害超集，覆盖 Cursor 实际消费的候选字段）。
#    ⚠️ 确切消费字段为 HYPOTHESIS（官网 schema 段落被截断无法逐字确认，
#    且有上游投递 bug #155689/#156157）——需 Cursor 侧实测确认（见 implementation.md 自验清单）。
#
# AC-S3：active-workflow 存在且 current-status.json 可读 → 注入状态表
#        （slug / 描述 / current_stage / current_phase / HG-1/2/3 / loop_count）。
# AC-S4：active-workflow 或 current-status.json 不存在 → 静默（输出空 JSON {}，不报错、不伪造）。
# AC-F4 边界：文件存在但损坏/缺字段 → fail-loud（注入明确错误提示 JSON），不注入伪造全 pending。
#
# 本 Phase（phase-1-sessionstart）只注入状态表；流程/角色锚定块（emit_anchoring_block）
# 由 Phase 2 追加，本 Phase 绝不调用。
# ============================================

# ── source 共享状态读取片段（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/status-read.sh
source "$HOOK_DIR/lib/status-read.sh"

# ── OPT-2：用 HOOK_DIR 反推项目根（本脚本位于 <root>/.cursor/hooks/）──
# 避免新终端 cwd 不在项目根时读不到 active-workflow（相对路径隐患）。
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"

# ── 非阻塞读入 stdin 事件 JSON（读入但不解析，避免阻塞）──
INPUT=$(cat 2>/dev/null || echo '{}')

# ── emit_recovery_json：决策 1 双字段注入的唯一出口 ──
# 入参 $1 = 注入正文（可含换行）。用 jq --arg 安全转义为合法 JSON 字符串，
# 同时写入 hookSpecificOutput.additionalContext（嵌套）与顶层 additionalContext（镜像）。
# 无 jq 时降级为 emit '{}'（不注入 > 注入非法 JSON）。
emit_recovery_json() {
    local body="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg ctx "$body" \
            '{hookSpecificOutput:{hookEventName:"sessionStart",additionalContext:$ctx},additionalContext:$ctx}'
    else
        # jq 不可用（理论上不会：read_status 也依赖 jq）→ 输出空 JSON，保证合法 + exit 0
        echo '{}'
    fi
}

# ── 检查是否有活跃工作流（AC-S4 边界：无 → 静默）──
ACTIVE_FILE="$PROJECT_ROOT/.specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    echo '{}'
    exit 0
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
if [ -z "$SLUG" ]; then
    # active-workflow 存在但为空 → 无可恢复目标，静默（AC-S4 边界）
    echo '{}'
    exit 0
fi

SPEC_DIR="$PROJECT_ROOT/.specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"

# ── 状态文件不存在 → 静默（AC-S4 边界）──
if [ ! -f "$STATUS_FILE" ]; then
    echo '{}'
    exit 0
fi

# ── 通过共享片段读取状态（fail-loud，AC-F4）──
# read_status 用 if 包裹（AC-F5 调用约定，绝不裸调用）。
# 文件存在但损坏/缺字段 → 注入明确错误提示 JSON，绝不注入伪造全 pending 状态表。
if ! read_status "$STATUS_FILE" 2>/tmp/.cursor-session-read.err; then
    ERR_MSG=$(cat /tmp/.cursor-session-read.err 2>/dev/null)
    FAIL_BODY=$(cat <<FAILMSG
⚠️ 状态文件读取失败 — 无法注入可信恢复上下文

无法读取 \`$STATUS_FILE\`（JSON 损坏或缺失关键字段）。
为避免伪造的全 pending 状态污染恢复流程，未注入任何状态表。

错误详情:
$ERR_MSG

请人工检查 \`$STATUS_FILE\` 是否损坏（JSON 非法）或缺失关键字段
（.human_gates 含 hg1/hg2/hg3、.current_stage），修复后重新开始会话。
FAILMSG
)
    emit_recovery_json "$FAIL_BODY"
    exit 0
fi

# ── 成功路径：注入恢复状态表（AC-S3）──
# 本 Phase 仅注入状态表；流程/角色锚定块（emit_anchoring_block）由 Phase 2 追加。
RECOVERY_BODY=$(cat <<RECOVERY
📌 活跃工作流检测到 — 自动恢复上下文（sessionStart）

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

请先读取 \`.specdev/specs/$SLUG/current-status.json\` 确认完整状态后再继续操作。
如用户未要求特定操作，请向用户简要报告当前进度并等待指示。
RECOVERY
)

emit_recovery_json "$RECOVERY_BODY"
exit 0
