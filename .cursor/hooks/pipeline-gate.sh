#!/bin/bash
# ============================================
# pipeline-gate.sh — Human Gate 程序化门禁 v5
# 绑定: preToolUse (matcher: Task + Shell)
# schema: .specdev/specs/{slug}/current-status.json
# failClosed: true — hook 崩溃 = deny
# v6: git commit/push 拦截改用文件标记 /tmp/git-commit-allowed（env var 跨进程不可传递）
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
    # ── git commit/push 必须经用户显式允许 ──
    if echo "$CMD" | grep -qE '\bgit (commit|push)\b'; then
        # 文件标记：/tmp/git-commit-allowed 存在且 300s 内创建则放行
        if [ -f /tmp/git-commit-allowed ] && [ $(($(date +%s) - $(stat -c %Y /tmp/git-commit-allowed 2>/dev/null || echo 0))) -lt 300 ]; then
            echo '{"permission":"allow"}'
            exit 0
        fi
        cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ git commit/push 被拦截。Agent 不允许未经用户明确同意的提交操作。\\n如你确实需要提交，请回复「允许提交」后由 Agent touch /tmp/git-commit-allowed 再执行。"}
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

# ── Phase ID 校验函数 ──
# 验证 $CURRENT_PHASE 是否存在于 phase-plan.md DAG JSON 的 phases[].id 中
# 参数: $1 = "warn" 只警告 | "deny" 阻断
# 返回: 0 = 合法, 1 = 非法
validate_phase_id() {
    local action="${1:-deny}"

    # 没有 current_phase → 这意味着 implementer 还没被调度过，放行
    if [ -z "$CURRENT_PHASE" ]; then
        return 0
    fi

    local DAG_FILE="$SPEC_DIR/phase-plan.md"
    if [ ! -s "$DAG_FILE" ]; then
        return 0  # 还没生成 phase-plan，放行
    fi

    # 提取 DAG JSON 中的 phases[].id 列表
    local VALID_IDS
    VALID_IDS=$(sed -n '/```json/,/```/p' "$DAG_FILE" | jq -r '.phases[].id' 2>/dev/null)

    if [ -z "$VALID_IDS" ]; then
        return 0  # 无法解析，放行
    fi

    if echo "$VALID_IDS" | grep -qxF "$CURRENT_PHASE"; then
        return 0  # 合法
    fi

    # 非法 Phase ID
    local VALID_LIST
    VALID_LIST=$(echo "$VALID_IDS" | tr '\n' ' ')
    if [ "$action" = "warn" ]; then
        cat <<BLOCK
{"permission":"allow","warning":"⚠️ Phase ID \\\`$CURRENT_PHASE\\\` 不在 phase-plan.md DAG JSON 的 phases[].id 列表中（有效 ID: $VALID_LIST）。请确保 ID 来自 DAG JSON，避免文件夹分裂。"}
BLOCK
    else
        cat <<BLOCK
{"permission":"deny","user_message":"⛔ Phase ID 不合法：\\\`$CURRENT_PHASE\\\` 不在 phase-plan.md DAG JSON 的 phases[].id 列表中。\\n有效的 Phase ID：$VALID_LIST\\n请将 current_phase 改回 DAG JSON 中的 ID（ID 是 plan-generator 先产出的唯一标准，禁止自己编名字）。","agent_message":"current_phase '$CURRENT_PHASE' is not a valid DAG phase id. Valid ids: $VALID_LIST. Use the id from phase-plan.md DAG JSON."}
BLOCK
    fi
    return 1
}

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
        # Phase ID 必须来自 DAG JSON（禁止自己编名字）
        VALIDATE_OUT=$(validate_phase_id deny)
        VALIDATE_RC=$?
        if [ $VALIDATE_RC -ne 0 ]; then
            echo "$VALIDATE_OUT"
            exit 0
        fi
        # loop_count 上限
        if [ "$LOOP_COUNT" -ge 2 ]; then
            cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 回路计数已达上限（2轮）。请向用户报告问题并请求指导。","agent_message":"Loop count exceeded (max 2). Escalate to user."}
BLOCK
            exit 0
        fi
        # ── Git 分支校验：implementer 必须在 impl-<phase-id> 分支上工作 ──
        EXPECTED_BRANCH="impl-${CURRENT_PHASE}"
        ACTUAL_BRANCH=$(git branch --show-current 2>/dev/null)
        if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
            cat <<BLOCK
{"permission":"deny","user_message":"⛔ Git 分支不匹配：当前分支是 \\\`$ACTUAL_BRANCH\\\`，但 implementer 必须在 \\\`$EXPECTED_BRANCH\\\` 分支上工作。\\n请调度者先创建分支：\\\`git checkout -b $EXPECTED_BRANCH\\\` 后再重新委托 implementer。","agent_message":"Wrong git branch. Currently on '$ACTUAL_BRANCH', expected '$EXPECTED_BRANCH'. Branch must be created by orchestrator before dispatching implementer."}
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
        # Phase ID 校验
        VALIDATE_OUT=$(validate_phase_id deny)
        VALIDATE_RC=$?
        if [ $VALIDATE_RC -ne 0 ]; then
            echo "$VALIDATE_OUT"
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
        # Phase ID 校验
        VALIDATE_OUT=$(validate_phase_id deny)
        VALIDATE_RC=$?
        if [ $VALIDATE_RC -ne 0 ]; then
            echo "$VALIDATE_OUT"
            exit 0
        fi
        echo '{"permission":"allow"}'
        ;;

    code-explorer)
        # Phase ID 校验（仅警告，不阻断——code-explorer 是调研阶段）
        validate_phase_id warn
        echo '{"permission":"allow"}'
        ;;

    *)
        echo '{"permission":"allow"}'
        ;;
esac

exit 0
