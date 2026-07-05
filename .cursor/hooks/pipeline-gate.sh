#!/bin/bash
# ============================================
# pipeline-gate.sh — Human Gate 程序化门禁 v4
# 绑定: preToolUse (matcher: Task + Shell)
# schema: .specdev/specs/{slug}/current-status.json
# failClosed: true — hook 崩溃 = deny
# ============================================

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ── Shell 安全检查 ──
if [ "$TOOL_NAME" = "Shell" ]; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    if echo "$CMD" | grep -qE 'rm -rf /[^a-z]|sudo rm -rf|:\(\)\{ :|:& \};:'; then
        cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 危险命令被拦截"}
BLOCK
        exit 0
    fi
    echo '{"permission":"allow"}'
    exit 0
fi

# ── 只拦截 Task ──
if [ "$TOOL_NAME" != "Task" ]; then
    echo '{"permission":"allow"}'
    exit 0
fi

# ── 解析子Agent ──
TOOL_INPUT_RAW=$(echo "$INPUT" | jq -r '.tool_input // "{}"')
SUBAGENT=$(echo "$TOOL_INPUT_RAW" | jq -r '.subagent_type // empty' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(echo "$TOOL_INPUT_RAW" | jq -r '.subagent_name // empty' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(echo "$TOOL_INPUT_RAW" | grep -oP '\b(implementer|reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|verifier|plan-generator|requirement-analyst|code-explorer)\b' | head -1)

# 内置agent放行
case "$SUBAGENT" in
    explore|bash|browser|generalPurpose) echo '{"permission":"allow"}'; exit 0 ;;
esac

KNOWN="implementer|reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|verifier|plan-generator|requirement-analyst|code-explorer"
if ! echo "$SUBAGENT" | grep -qP "^($KNOWN)$"; then
    echo '{"permission":"allow"}'
    exit 0
fi

# ── 加载活跃工作流 ──
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    case "$SUBAGENT" in
        requirement-analyst|code-explorer) echo '{"permission":"allow"}'; exit 0 ;;
        *) cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 无活跃工作流。请先使用 /feature 或 /bugfix 命令初始化。","agent_message":"No active workflow. Use /feature or /bugfix first."}
BLOCK
        exit 0 ;;
    esac
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
SPEC_DIR=".specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"

if [ ! -f "$STATUS_FILE" ]; then
    case "$SUBAGENT" in
        requirement-analyst|code-explorer) echo '{"permission":"allow"}'; exit 0 ;;
        *) cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 工作流状态文件缺失。请确保 /feature 或 /bugfix 命令已正确初始化。","agent_message":"Workflow status file missing. Verify pipeline initialization."}
BLOCK
        exit 0 ;;
    esac
fi

# ── jq 解析状态 ──
HG1=$(jq -r '.human_gates.hg1' "$STATUS_FILE" 2>/dev/null)
HG2=$(jq -r '.human_gates.hg2' "$STATUS_FILE" 2>/dev/null)
HG3=$(jq -r '.human_gates.hg3' "$STATUS_FILE" 2>/dev/null)
CURRENT_PHASE=$(jq -r '.current_phase // ""' "$STATUS_FILE" 2>/dev/null)
LOOP_COUNT=$(jq -r '.loop_count // 0' "$STATUS_FILE" 2>/dev/null)

# ── Human Gate 门禁 ──
case "$SUBAGENT" in
    requirement-analyst)
        echo '{"permission":"allow"}'
        ;;

    plan-generator)
        REQ_FILE="$SPEC_DIR/requirements.md"
        if [ "$HG1" = "passed" ]; then
            echo '{"permission":"allow"}'
        elif [ -s "$REQ_FILE" ]; then
            echo '{"permission":"allow"}'
        else
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ Human Gate 1 未通过。请先与用户确认需求（requirements.md），用户明确说「确认」后才能进入架构设计。","agent_message":"HG-1 not passed. Wait for user confirmation on requirements."}
BLOCK
        fi
        ;;

    implementer)
        if [ "$HG2" != "passed" ]; then
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ Human Gate 2 未通过。请先向用户展示设计方案（design.md + phase-plan.md），等待用户明确说「确认」「开始实施」。","agent_message":"HG-2 not passed. Present design to user for confirmation first."}
BLOCK
            exit 0
        fi
        # Phase N (N>1) 需要上 Phase HG-3
        if echo "$CURRENT_PHASE" | grep -qP 'phase-[2-9]' && [ "$HG3" != "passed" ]; then
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 上一 Phase 尚未通过 HG-3 验收。请先完成当前 Phase 的验证并等待用户确认。","agent_message":"Previous phase HG-3 not passed. Complete verification and get approval first."}
BLOCK
            exit 0
        fi
        # loop_count 上限
        if [ "$LOOP_COUNT" -ge 2 ]; then
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 回路计数已达上限（2轮）。请向用户报告问题并请求指导。","agent_message":"Loop count exceeded (max 2). Escalate to user."}
BLOCK
            exit 0
        fi
        echo '{"permission":"allow"}'
        ;;

    reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity)
        IMPL_FILE="$SPEC_DIR/phases/$CURRENT_PHASE/implementation.md"
        if [ ! -s "$IMPL_FILE" ]; then
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 无 implementation.md（或文件为空）。请先委托 implementer 完成代码实现。","agent_message":"No non-empty implementation.md. Dispatch implementer first."}
BLOCK
            exit 0
        fi
        echo '{"permission":"allow"}'
        ;;

    verifier)
        REVIEW_FILE="$SPEC_DIR/phases/$CURRENT_PHASE/review.md"
        if [ ! -s "$REVIEW_FILE" ]; then
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 无 review.md（或文件为空）。请先委托 reviewer 完成代码审查。","agent_message":"No non-empty review.md. Dispatch reviewer first."}
BLOCK
            exit 0
        fi
        # 检查判决
        VERDICT=$(grep -oP '判决.*?\*\*\s*\K[^*]+' "$REVIEW_FILE" 2>/dev/null | head -1 | tr -d ' ')
        if [ "$VERDICT" = "MUST-FIX" ]; then
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 审查判决为 MUST-FIX。请先委托 implementer 修复后重新审查。","agent_message":"Review verdict is MUST-FIX. Fix and re-review before verification."}
BLOCK
            exit 0
        fi
        echo '{"permission":"allow"}'
        ;;

    code-explorer)
        echo '{"permission":"allow"}'
        ;;

    *)
        echo '{"permission":"allow"}'
        ;;
esac

exit 0
