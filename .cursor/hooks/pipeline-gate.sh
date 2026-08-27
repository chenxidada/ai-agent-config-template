#!/bin/bash
# ============================================
# pipeline-gate.sh — Human Gate 程序化门禁 v7
# 绑定: preToolUse (matcher: Task + Shell + Edit + Write)
# schema: .specdev/specs/{slug}/current-status.json
# failClosed: true — hook 崩溃 = deny
#
# v7 增强（同步 Trae v2）:
# 1. 阶段跳跃检测 — 严格顺序校验
# 2. 内容完整性校验 — 前置文件必须含有效内容标记
# 3. 心跳/超时提醒 — 记录最后活动时间戳
# 4. current-status.json 更新时完整流程校验
# 5. 阶段一致性检查
#
# AC-F3/F5：状态读取收敛到共享 read_status（lib/status-read.sh），
#   消除 gate 内两处 .human_gates.hgN 内联 jq 读取的漂移点。
#   本 hook 未启用 set -euo pipefail（保持 Cursor 现状），但 read_status
#   仍用 if/|| 包裹，读取失败时降级到与原内联读取等价的安全默认值，
#   绝不破坏 allow/deny (permission JSON) 契约。
# ============================================

# ── source 共享状态读取片段（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/status-read.sh
source "$HOOK_DIR/lib/status-read.sh"
# shellcheck source=lib/verdict-parse.sh
# Class C：verifier 判决解析（parse_verdict / max_residual_severity /
# verdict_is_self_inconsistent）→ HG-3 门禁按 Q-3 用 ask 暴露非 PASS/缺判决/自相矛盾
source "$HOOK_DIR/lib/verdict-parse.sh"

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ── 心跳机制：记录最后活动时间戳 ──
HEARTBEAT_FILE="/tmp/.cursor-pipeline-heartbeat"
HEARTBEAT_TIMEOUT=180  # 3分钟无活动视为超时
HEARTBEAT_MSG=""

update_heartbeat() {
    date +%s > "$HEARTBEAT_FILE"
}

check_heartbeat() {
    if [ ! -f "$HEARTBEAT_FILE" ]; then
        update_heartbeat
        return
    fi
    local LAST_ACTIVE
    LAST_ACTIVE=$(cat "$HEARTBEAT_FILE" 2>/dev/null || echo "0")
    local NOW
    NOW=$(date +%s)
    local ELAPSED=$((NOW - LAST_ACTIVE))
    if [ "$ELAPSED" -gt "$HEARTBEAT_TIMEOUT" ]; then
        HEARTBEAT_MSG="⏰ 距上次活动已 ${ELAPSED}s（超过 ${HEARTBEAT_TIMEOUT}s）。如果卡住了，请检查：1) 是否在等待用户确认 Human Gate？2) 是否有子Agent 未返回？3) 当前阶段是否需要调整？"
    fi
    update_heartbeat
}

check_heartbeat

# ── 辅助函数：内容完整性检查 ──
check_file_valid() {
    local FILE="$1"
    local MIN_LINES="${2:-5}"
    local REQUIRED_MARKER="${3:-}"

    if [ ! -f "$FILE" ]; then
        return 1
    fi
    local LINE_COUNT
    LINE_COUNT=$(wc -l < "$FILE" 2>/dev/null || echo "0")
    if [ "$LINE_COUNT" -lt "$MIN_LINES" ]; then
        return 1
    fi
    if [ -n "$REQUIRED_MARKER" ]; then
        if ! grep -q "$REQUIRED_MARKER" "$FILE" 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

# ── 辅助函数：允许（附带心跳提醒） ──
allow_with_heartbeat() {
    if [ -n "$HEARTBEAT_MSG" ]; then
        echo "{\"permission\":\"allow\",\"agent_message\":\"$HEARTBEAT_MSG\"}"
    else
        echo '{"permission":"allow"}'
    fi
    exit 0
}

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
        if [ -f /tmp/git-commit-allowed ] && [ $(($(date +%s) - $(stat -c %Y /tmp/git-commit-allowed 2>/dev/null || echo 0))) -lt 300 ]; then
            allow_with_heartbeat
        fi
        cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ git commit/push 被拦截。Agent 不允许未经用户明确同意的提交操作。\\n如你确实需要提交，请回复「允许提交」后由 Agent touch /tmp/git-commit-allowed 再执行。"}
BLOCK
        exit 0
    fi
    allow_with_heartbeat
fi

# ── Edit/Write 文件门禁（current-status.json 完整流程校验） ──
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
    TARGET_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
    
    # current-status.json 的更新 → 严格校验完整流程
    if echo "$TARGET_FILE" | grep -q "current-status\.json$"; then
        ACTIVE_FILE=".specdev/active-workflow"
        if [ -f "$ACTIVE_FILE" ]; then
            SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
            SPEC_DIR=".specdev/specs/$SLUG"
            STATUS_FILE="$SPEC_DIR/current-status.json"
            
            if [ -f "$STATUS_FILE" ]; then
                # 收敛到共享 read_status（AC-F3）。读取失败（损坏/缺字段）时
                # 降级到与原内联读取等价的安全默认值，保持本段门禁行为不变。
                if ! read_status "$STATUS_FILE" 2>/dev/null; then
                    CURRENT_PHASE=""
                    HG1="pending"; HG2="pending"; HG3="pending"
                fi
                
                NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_str // empty' 2>/dev/null)
                
                # ── AC-E9：verifier 失败回路上限硬阻断（镜像 .trae 的 IS_ADVANCE 结构）──
                # 当 verifier_loop_count >= 2 且本次写入是「推进动作」（hg3=passed 或 current_phase 切换）时，
                # deny 硬停死循环，逼迫用户介入。与 Class C 的 ask 校验隔离：ask 针对判决内容，本 deny 针对回路次数。
                if [ -n "$NEW_CONTENT" ]; then
                    VLC=$(echo "$NEW_CONTENT" | jq -r '.verifier_loop_count // empty' 2>/dev/null)
                    if [ -z "$VLC" ] && [ -f "$STATUS_FILE" ]; then
                        VLC=$(jq -r '.verifier_loop_count // 0' "$STATUS_FILE" 2>/dev/null)
                    fi
                    [ -z "$VLC" ] && VLC=0
                    case "$VLC" in
                        ''|*[!0-9]*) VLC=0 ;;
                    esac
                    IS_ADVANCE=0
                    if echo "$NEW_CONTENT" | grep -q '"hg3".*"passed"'; then
                        IS_ADVANCE=1
                    else
                        NEW_PHASE=$(echo "$NEW_CONTENT" | jq -r '.current_phase // empty' 2>/dev/null)
                        if [ -n "$NEW_PHASE" ] && [ -n "$CURRENT_PHASE" ] && [ "$NEW_PHASE" != "$CURRENT_PHASE" ]; then
                            IS_ADVANCE=1
                        fi
                    fi
                    if [ "$IS_ADVANCE" -eq 1 ] && [ "$VLC" -ge 2 ]; then
                        echo "{\"permission\":\"deny\",\"user_message\":\"⛔ verifier 验证循环已达上限（verifier_loop_count=$VLC >= 2）。请用户介入决定下一步。\"}"
                        exit 0
                    fi
                fi

                # 检查是否试图设置 hg3=passed
                if echo "$NEW_CONTENT" | grep -q '"hg3".*"passed"'; then
                    if [ -n "$CURRENT_PHASE" ]; then
                        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
                        if ! check_file_valid "$PHASE_DIR/implementation.md" 10 "##"; then
                            echo '{"permission":"deny","user_message":"⛔ 流程不完整：尝试标记 HG-3 通过，但 implementation.md 不存在或内容无效。必须完成 implementer → reviewer → verifier 完整流程。"}'
                            exit 0
                        fi
                        if ! check_file_valid "$PHASE_DIR/review.md" 5 "判决"; then
                            echo '{"permission":"deny","user_message":"⛔ 流程不完整：尝试标记 HG-3 通过，但 review.md 不存在或缺少「判决」。必须先完成 reviewer 审查。"}'
                            exit 0
                        fi
                        if ! check_file_valid "$PHASE_DIR/verification.md" 5; then
                            echo '{"permission":"deny","user_message":"⛔ 流程不完整：尝试标记 HG-3 通过，但 verification.md 不存在。必须先完成 verifier 独立验证。"}'
                            exit 0
                        fi
                        VERDICT=$(grep -oP '判决.*?\*\*\s*\K[^*]+' "$PHASE_DIR/review.md" 2>/dev/null | head -1 | tr -d ' ')
                        if [ "$VERDICT" = "MUST-FIX" ]; then
                            echo '{"permission":"deny","user_message":"⛔ 流程不完整：review.md 判决为 MUST-FIX，不能标记 HG-3 通过。请先修复并重新审查。"}'
                            exit 0
                        fi

                        # ── Class C：verifier 判决校验（Q-3 用 ask，绝不 deny）──
                        # 门禁是兜底非硬拦截：暴露 verifier 判决问题让用户决定，不硬堵 HG-3。
                        # 校验顺序：无判决 → 非 PASS → 自相矛盾（ask exit 0，第一个触发者胜出）。
                        VERI_FILE="$PHASE_DIR/verification.md"
                        V_VERDICT=$(parse_verdict "$VERI_FILE" || echo "")
                        if [ -z "$V_VERDICT" ]; then
                            # AC-15：无可解析判决
                            echo "{\"permission\":\"ask\",\"user_message\":\"⚠️ HG-3 触发条件【缺失判决】：verification.md 无可解析的判决字段（判决行缺失，或残留多值枚举）。verifier 必须报告单一判决值。是否仍标记 HG-3 通过？\"}"
                            exit 0
                        elif [ "$V_VERDICT" != "PASS" ]; then
                            # AC-14：判决非 PASS
                            echo "{\"permission\":\"ask\",\"user_message\":\"⚠️ HG-3 触发条件【非 PASS】：verifier 判决为 $V_VERDICT（非 PASS）。$V_VERDICT 表示验收标准未全部达成或存在未解决 Known Gaps。是否仍标记 HG-3 通过？\"}"
                            exit 0
                        elif verdict_is_self_inconsistent "$VERI_FILE"; then
                            # AC-16：判决=PASS 但残余含 CRITICAL/MEDIUM
                            V_SEV=$(max_residual_severity "$VERI_FILE")
                            echo "{\"permission\":\"ask\",\"user_message\":\"⚠️ HG-3 触发条件【自相矛盾】：verifier 判决=PASS 但残余风险区含 $V_SEV 级风险。判决与残余风险自相矛盾。是否仍标记 HG-3 通过？\"}"
                            exit 0
                        fi
                    fi
                fi
                
                # 检查是否试图设置 hg2=passed
                if echo "$NEW_CONTENT" | grep -q '"hg2".*"passed"'; then
                    if ! check_file_valid "$SPEC_DIR/design.md" 10 "##"; then
                        echo '{"permission":"deny","user_message":"⛔ 流程不完整：尝试标记 HG-2 通过，但 design.md 不存在或内容无效。"}'
                        exit 0
                    fi
                    if ! check_file_valid "$SPEC_DIR/phase-plan.md" 10; then
                        echo '{"permission":"deny","user_message":"⛔ 流程不完整：尝试标记 HG-2 通过，但 phase-plan.md 不存在。"}'
                        exit 0
                    fi
                fi
                
                # 检查是否试图设置 hg1=passed
                if echo "$NEW_CONTENT" | grep -q '"hg1".*"passed"'; then
                    if ! check_file_valid "$SPEC_DIR/requirements.md" 10 "##"; then
                        echo '{"permission":"deny","user_message":"⛔ 流程不完整：尝试标记 HG-1 通过，但 requirements.md 不存在或内容无效。"}'
                        exit 0
                    fi
                fi
                
                # 检查是否在切换 current_phase
                if echo "$NEW_CONTENT" | grep -q '"current_phase"'; then
                    if [ -n "$CURRENT_PHASE" ] && [ "$HG3" = "pending" ]; then
                        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
                        if [ -f "$PHASE_DIR/implementation.md" ] && ! check_file_valid "$PHASE_DIR/verification.md" 5; then
                            echo '{"permission":"deny","user_message":"⛔ 阶段跳跃：当前 Phase 的 verifier 尚未完成，不能切换到下一个 Phase。完整流程：implementer → reviewer → verifier → HG-3 用户确认。"}'
                            exit 0
                        fi
                    fi
                fi
            fi
        fi
    fi
    allow_with_heartbeat
fi

# ── 只拦截 Task ──
if [ "$TOOL_NAME" != "Task" ]; then
    allow_with_heartbeat
fi

# ── 解析子Agent ──
TOOL_INPUT_RAW=$(echo "$INPUT" | jq -r '.tool_input // "{}"')
SUBAGENT=$(echo "$TOOL_INPUT_RAW" | jq -r '.subagent_type // empty' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(echo "$TOOL_INPUT_RAW" | jq -r '.subagent_name // empty' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(echo "$TOOL_INPUT_RAW" | grep -oP '\b(implementer|reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|verifier|plan-generator|requirement-analyst|code-explorer)\b' | head -1)

# 内置agent放行
case "$SUBAGENT" in
    explore|bash|browser|generalPurpose) allow_with_heartbeat ;;
esac

KNOWN="implementer|reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|verifier|plan-generator|requirement-analyst|code-explorer"
if ! echo "$SUBAGENT" | grep -qP "^($KNOWN)$"; then
    allow_with_heartbeat
fi

# ── 加载活跃工作流 ──
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    case "$SUBAGENT" in
        requirement-analyst|code-explorer) allow_with_heartbeat ;;
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
        requirement-analyst|code-explorer) allow_with_heartbeat ;;
        *) cat <<'BLOCK'
{"permission":"deny","user_message":"⛔ 工作流状态文件缺失。请确保 /feature 或 /bugfix 命令已完成初始化。"}
BLOCK
        exit 0 ;;
    esac
fi

# 读取状态（收敛到共享 read_status，AC-F3）
# failClosed:true 语义：状态损坏/缺字段时无法可信判定门禁，降级到安全默认值
# （全 pending / current_phase 空 / stage unknown），使下游 HG 校验对实施类
# Agent 保持「拒绝」（fail-closed），绝不误放行。read_status 用 if 包裹，绝不裸调用。
if ! read_status "$STATUS_FILE" 2>/dev/null; then
    HG1="pending"; HG2="pending"; HG3="pending"
    CURRENT_PHASE=""
    LOOP_COUNT=0
    CURRENT_STAGE="unknown"
fi

# ── 阶段一致性检查 ──
if [ "$CURRENT_STAGE" != "phase-implementation" ]; then
    case "$SUBAGENT" in
        implementer|reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|verifier)
            echo "{\"permission\":\"deny\",\"user_message\":\"⛔ 阶段不一致：当前处于 \`$CURRENT_STAGE\` 阶段，但尝试调度实施类 Agent($SUBAGENT)。请先完成需求确认(HG-1)和方案确认(HG-2)。\"}"
            exit 0
            ;;
    esac
fi

# ── Phase ID 校验 ──
validate_phase_id() {
    local MODE="${1:-deny}"
    if [ -z "$CURRENT_PHASE" ]; then
        if [ "$MODE" = "deny" ]; then
            echo '{"permission":"deny","user_message":"⛔ current-status.json 中 current_phase 为空。请先完成 Phase 拆分并设置 current_phase。"}'
            return 1
        fi
        return 0
    fi
    local DAG_FILE="$SPEC_DIR/phase-plan.md"
    if [ ! -s "$DAG_FILE" ]; then return 0; fi
    local VALID_IDS
    VALID_IDS=$(sed -n '/```json/,/```/p' "$DAG_FILE" | grep -v '```' | jq -r '.phases[].id' 2>/dev/null)
    if [ -z "$VALID_IDS" ]; then return 0; fi
    if echo "$VALID_IDS" | grep -qxF "$CURRENT_PHASE"; then return 0; fi
    local VALID_LIST
    VALID_LIST=$(echo "$VALID_IDS" | tr '\n' ' ')
    if [ "$MODE" = "warn" ]; then
        return 0
    fi
    echo "{\"permission\":\"deny\",\"user_message\":\"⛔ Phase ID 不合法：\`$CURRENT_PHASE\` 不在 phase-plan.md DAG JSON 中。有效 ID：$VALID_LIST\"}"
    return 1
}

# ── 按 Agent 类型校验 ──
case "$SUBAGENT" in
    requirement-analyst)
        allow_with_heartbeat
        ;;

    plan-generator)
        if [ "$HG1" != "passed" ]; then
            echo '{"permission":"deny","user_message":"⛔ Human Gate 1 未通过。请先确认需求文档后再进入设计阶段。"}'
            exit 0
        fi
        # 内容完整性：requirements.md 必须有效
        if ! check_file_valid "$SPEC_DIR/requirements.md" 10 "##"; then
            echo '{"permission":"deny","user_message":"⛔ 前置条件不满足：requirements.md 不存在或内容无效（少于10行或缺少结构化章节）。"}'
            exit 0
        fi
        allow_with_heartbeat
        ;;

    implementer)
        if [ "$HG2" != "passed" ]; then
            echo '{"permission":"deny","user_message":"⛔ Human Gate 2 未通过。请先确认设计方案后再开始实施。","agent_message":"HG-2 not passed. Confirm design first."}'
            exit 0
        fi
        if [ "$LOOP_COUNT" -ge 2 ]; then
            echo '{"permission":"deny","user_message":"⛔ 实施循环已达上限（loop_count >= 2）。请用户介入决定下一步。","agent_message":"Loop limit reached. Escalate to user."}'
            exit 0
        fi
        VALIDATE_OUT=$(validate_phase_id deny)
        VALIDATE_RC=$?
        if [ $VALIDATE_RC -ne 0 ]; then
            echo "$VALIDATE_OUT"
            exit 0
        fi
        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        if [ ! -f "$PHASE_DIR/spec.md" ]; then
            echo '{"permission":"deny","user_message":"⛔ Phase spec 不存在。请确保 plan-generator 已创建 phases/<phase>/spec.md。"}'
            exit 0
        fi
        # 阶段跳跃检测：必须有 repo-exploration.md（code-explorer 已完成）
        if ! check_file_valid "$PHASE_DIR/repo-exploration.md" 10; then
            echo '{"permission":"deny","user_message":"⛔ 阶段跳跃：repo-exploration.md 不存在或内容不足。请先委托 code-explorer 进行代码调研。"}'
            exit 0
        fi
        # Git 分支校验
        EXPECTED_BRANCH="impl-${CURRENT_PHASE}"
        ACTUAL_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ] && [ "$ACTUAL_BRANCH" != "unknown" ]; then
            echo "{\"permission\":\"deny\",\"user_message\":\"⛔ Git 分支不匹配：当前 \`$ACTUAL_BRANCH\`，需要 \`$EXPECTED_BRANCH\`。请先创建/切换分支。\"}"
            exit 0
        fi
        allow_with_heartbeat
        ;;

    reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity)
        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        # 阶段跳跃检测：implementation.md 必须有效（含结构化章节）
        if ! check_file_valid "$PHASE_DIR/implementation.md" 10 "##"; then
            echo '{"permission":"deny","user_message":"⛔ 阶段跳跃：implementation.md 不存在或内容无效。请先完成 implementer 实施。","agent_message":"No valid implementation.md. Dispatch implementer first."}'
            exit 0
        fi
        VALIDATE_OUT=$(validate_phase_id deny)
        VALIDATE_RC=$?
        if [ $VALIDATE_RC -ne 0 ]; then
            echo "$VALIDATE_OUT"
            exit 0
        fi
        allow_with_heartbeat
        ;;

    verifier)
        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        # 阶段跳跃检测：review.md 必须有效且包含判决
        if ! check_file_valid "$PHASE_DIR/review.md" 5 "判决"; then
            echo '{"permission":"deny","user_message":"⛔ 阶段跳跃：review.md 不存在或缺少「判决」字段。请先完成 reviewer 审查合并。","agent_message":"No valid review.md with verdict. Complete review first."}'
            exit 0
        fi
        VERDICT=$(grep -oP '判决.*?\*\*\s*\K[^*]+' "$PHASE_DIR/review.md" 2>/dev/null | head -1 | tr -d ' ')
        if [ "$VERDICT" = "MUST-FIX" ]; then
            echo '{"permission":"deny","user_message":"⛔ 审查判决为 MUST-FIX。请先委托 implementer 修复后重新审查。","agent_message":"Review verdict is MUST-FIX. Fix and re-review before verification."}'
            exit 0
        fi
        VALIDATE_OUT=$(validate_phase_id deny)
        VALIDATE_RC=$?
        if [ $VALIDATE_RC -ne 0 ]; then
            echo "$VALIDATE_OUT"
            exit 0
        fi
        allow_with_heartbeat
        ;;

    code-explorer)
        validate_phase_id warn
        allow_with_heartbeat
        ;;

    *)
        allow_with_heartbeat
        ;;
esac

exit 0
