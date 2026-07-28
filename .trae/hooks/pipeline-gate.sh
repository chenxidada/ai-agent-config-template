#!/bin/bash
# ============================================
# pipeline-gate.sh — Human Gate 程序化门禁 (Trae 版 v2)
# 绑定: PreToolUse (matcher: Write|Edit|RunCommand)
# schema: .specdev/specs/{slug}/current-status.json
#
# v2 增强:
# 1. 阶段跳跃检测 — 严格顺序校验，防止跳过 implementer 直接写 review
# 2. 内容完整性校验 — 前置文件不仅要存在，还要包含有效内容标记
# 3. 心跳/超时提醒 — 记录最后活动时间戳，超时注入提醒
#
# 协议: stdin JSON → stdout 文本(注入给Agent) + 退出码(0=allow, 非0=deny)
# ============================================

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)

cd "$CWD" 2>/dev/null || true

# ── 心跳机制：记录最后活动时间戳 ──
HEARTBEAT_FILE="/tmp/.trae-pipeline-heartbeat"
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
        HEARTBEAT_MSG="⏰ 距上次活动已 ${ELAPSED}s（超过 ${HEARTBEAT_TIMEOUT}s）。如果你卡住了，请检查：1) 是否在等待用户确认 Human Gate？2) 是否有子Agent 未返回？3) 当前阶段是否需要调整？"
    fi
    update_heartbeat
}

# 执行心跳检查
check_heartbeat

# ── 辅助函数：拒绝（非零退出码 = Trae deny） ──
deny() {
    echo "$1"
    exit 1
}

# ── 辅助函数：允许（附带心跳提醒） ──
allow() {
    local msg="${1:-}"
    if [ -n "$HEARTBEAT_MSG" ]; then
        if [ -n "$msg" ]; then
            echo -e "${msg}\n\n${HEARTBEAT_MSG}"
        else
            echo "$HEARTBEAT_MSG"
        fi
    else
        echo "${msg:-}"
    fi
    exit 0
}

# ── 辅助函数：内容完整性检查 ──
# 检查文件不仅存在，还包含有效内容
check_file_valid() {
    local FILE="$1"
    local MIN_LINES="${2:-5}"
    local REQUIRED_MARKER="${3:-}"

    if [ ! -f "$FILE" ]; then
        return 1
    fi
    # 文件必须非空且超过最小行数
    local LINE_COUNT
    LINE_COUNT=$(wc -l < "$FILE" 2>/dev/null || echo "0")
    if [ "$LINE_COUNT" -lt "$MIN_LINES" ]; then
        return 1
    fi
    # 如果指定了必需标记，检查是否存在
    if [ -n "$REQUIRED_MARKER" ]; then
        if ! grep -q "$REQUIRED_MARKER" "$FILE" 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

# ── 辅助函数：阶段顺序校验 ──
# 根据 current-status.json 中的 phases 状态判断是否存在跳跃
check_stage_sequence() {
    local WRITING_STAGE="$1"  # 当前正在写入哪个阶段的文件
    local PHASE_DIR="$2"

    case "$WRITING_STAGE" in
        "implementation")
            # 写 implementation 前：必须有 repo-exploration.md（code-explorer 已完成）
            if [ -d "$PHASE_DIR" ] && ! check_file_valid "$PHASE_DIR/repo-exploration.md" 10; then
                deny "⛔ 阶段跳跃：尝试写 implementation.md 但 code-explorer 尚未完成（repo-exploration.md 不存在或内容不足）。请先委托 code-explorer 进行代码调研。"
            fi
            ;;
        "review")
            # 写 review 前：必须有有效的 implementation.md（含「变更清单」或「Changes」标记）
            if ! check_file_valid "$PHASE_DIR/implementation.md" 10 "##"; then
                deny "⛔ 阶段跳跃：尝试写 review 但 implementation.md 不存在或内容无效（缺少结构化章节）。请先完成实施。"
            fi
            ;;
        "verification")
            # 写 verification 前：必须有合并后的 review.md 且包含「判决」标记
            if ! check_file_valid "$PHASE_DIR/review.md" 5 "判决"; then
                deny "⛔ 阶段跳跃：尝试写 verification.md 但 review.md 不存在或缺少「判决」字段。请先完成审查合并。"
            fi
            ;;
    esac
}

# ── Shell/RunCommand 安全检查 ──
if [ "$TOOL_NAME" = "RunCommand" ]; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    # 危险命令拦截
    if echo "$CMD" | grep -qE 'rm -rf /[^a-z]|sudo rm -rf|:\(\)\{ :|:& \};:'; then
        deny "⛔ 危险命令被拦截"
    fi
    # ── git commit/push 必须经用户显式允许 ──
    if echo "$CMD" | grep -qE '\bgit (commit|push)\b'; then
        # 文件标记：/tmp/git-commit-allowed 存在且 300s 内创建则放行
        if [ -f /tmp/git-commit-allowed ] && [ $(($(date +%s) - $(stat -c %Y /tmp/git-commit-allowed 2>/dev/null || echo 0))) -lt 300 ]; then
            allow
        fi
        deny "⛔ git commit/push 被拦截。Agent 不允许未经用户明确同意的提交操作。\n如你确实需要提交，请回复「允许提交」后由 Agent touch /tmp/git-commit-allowed 再执行。"
    fi
    allow
fi

# ── 只对 Write 和 Edit 做流程门禁校验 ──
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
    allow
fi

# ── 提取目标文件路径 ──
TARGET_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$TARGET_FILE" ] && allow  # 无法确定路径，放行

# ── 非 .specdev/ 路径的文件：仅检查 git 分支 ──
if ! echo "$TARGET_FILE" | grep -q '\.specdev/'; then
    # 项目代码文件：检查是否在正确的 impl- 分支上
    ACTIVE_FILE=".specdev/active-workflow"
    if [ ! -f "$ACTIVE_FILE" ]; then
        allow  # 无工作流，不拦截普通编辑
    fi
    SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
    STATUS_FILE=".specdev/specs/$SLUG/current-status.json"
    if [ ! -f "$STATUS_FILE" ]; then
        allow
    fi

    CURRENT_PHASE=$(jq -r '.current_phase // ""' "$STATUS_FILE" 2>/dev/null)
    HG2=$(jq -r '.human_gates.hg2 // "pending"' "$STATUS_FILE" 2>/dev/null)

    # 如果 HG-2 已通过（进入实施阶段），项目代码必须在 impl- 分支上修改
    if [ "$HG2" = "passed" ] && [ -n "$CURRENT_PHASE" ]; then
        EXPECTED_BRANCH="impl-${CURRENT_PHASE}"
        ACTUAL_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ] && [ "$ACTUAL_BRANCH" != "unknown" ]; then
            deny "⛔ Git 分支不匹配：当前分支是 \`$ACTUAL_BRANCH\`，但实施阶段必须在 \`$EXPECTED_BRANCH\` 分支上工作。请先执行 \`git checkout -b $EXPECTED_BRANCH\` 或 \`git checkout $EXPECTED_BRANCH\`。"
        fi
    fi
    allow
fi

# ── .specdev/ 路径的文件：按文件路径推断 Agent 角色并校验前置条件 ──
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    allow
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
SPEC_DIR=".specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"

if [ ! -f "$STATUS_FILE" ]; then
    allow
fi

# 解析状态
HG1=$(jq -r '.human_gates.hg1 // "pending"' "$STATUS_FILE" 2>/dev/null)
HG2=$(jq -r '.human_gates.hg2 // "pending"' "$STATUS_FILE" 2>/dev/null)
HG3=$(jq -r '.human_gates.hg3 // "pending"' "$STATUS_FILE" 2>/dev/null)
CURRENT_PHASE=$(jq -r '.current_phase // ""' "$STATUS_FILE" 2>/dev/null)
LOOP_COUNT=$(jq -r '.loop_count // 0' "$STATUS_FILE" 2>/dev/null)
CURRENT_STAGE=$(jq -r '.current_stage // "unknown"' "$STATUS_FILE" 2>/dev/null)

# ── Phase ID 校验（从 DAG JSON 验证合法性） ──
validate_phase_id() {
    local MODE="${1:-deny}"

    if [ -z "$CURRENT_PHASE" ]; then
        if [ "$MODE" = "deny" ]; then
            deny "⛔ current-status.json 中 current_phase 为空。请先完成 Phase 拆分。"
        else
            return 0
        fi
    fi

    local DAG_FILE="$SPEC_DIR/phase-plan.md"
    if [ ! -s "$DAG_FILE" ]; then
        return 0
    fi

    local VALID_IDS
    VALID_IDS=$(sed -n '/```json/,/```/p' "$DAG_FILE" | grep -v '```' | jq -r '.phases[].id' 2>/dev/null)

    if [ -z "$VALID_IDS" ]; then
        return 0
    fi

    if echo "$VALID_IDS" | grep -qxF "$CURRENT_PHASE"; then
        return 0
    fi

    local VALID_LIST
    VALID_LIST=$(echo "$VALID_IDS" | tr '\n' ' ')
    if [ "$MODE" = "warn" ]; then
        echo "⚠️ Phase ID \`$CURRENT_PHASE\` 不在 DAG JSON 中（有效: $VALID_LIST）" >&2
        return 0
    else
        deny "⛔ Phase ID 不合法：\`$CURRENT_PHASE\` 不在 phase-plan.md DAG JSON 中。有效 ID：$VALID_LIST。"
    fi
}

# ── 阶段一致性校验（防止跨阶段操作） ──
# 如果 current_stage 不是 phase-implementation，禁止写 implementation/review/verification
if [ "$CURRENT_STAGE" != "phase-implementation" ]; then
    if echo "$TARGET_FILE" | grep -qE "(implementation|review|verification)\.md$"; then
        deny "⛔ 阶段不一致：当前处于 \`$CURRENT_STAGE\` 阶段，但尝试写入实施阶段文件。请先完成需求确认(HG-1)和方案确认(HG-2)。"
    fi
fi

# ── 按目标文件路径推断操作类型并校验 ──

# 写入 design.md / phase-plan.md → plan-generator 角色 → 需要 HG-1 已过
if echo "$TARGET_FILE" | grep -qE "(design\.md|phase-plan\.md)$"; then
    if [ "$HG1" != "passed" ]; then
        deny "⛔ Human Gate 1 未通过。请先确认需求文档后再进入设计阶段。"
    fi
    # 内容完整性：requirements.md 必须有效（至少10行，包含 ## 标记）
    if ! check_file_valid "$SPEC_DIR/requirements.md" 10 "##"; then
        deny "⛔ 前置条件不满足：requirements.md 不存在或内容无效（少于10行或缺少结构化章节）。"
    fi
    allow
fi

# 写入 requirements.md → requirement-analyst 角色 → 无前置条件，放行
if echo "$TARGET_FILE" | grep -q "requirements\.md$"; then
    allow
fi

# 写入 repo-exploration.md → code-explorer 角色 → 仅警告 Phase ID
if echo "$TARGET_FILE" | grep -q "repo-exploration"; then
    # HG-2 必须已过才能写 phase 目录下的 repo-exploration
    if echo "$TARGET_FILE" | grep -q "/phases/" && [ "$HG2" != "passed" ]; then
        deny "⛔ Human Gate 2 未通过。请先确认设计方案后再进行 Phase 代码调研。"
    fi
    validate_phase_id warn
    allow
fi

# 写入 spec.md（phase spec）→ plan-generator 产出 → 需要 HG-1 已过
if echo "$TARGET_FILE" | grep -qE "phases/.*/spec\.md$"; then
    if [ "$HG1" != "passed" ]; then
        deny "⛔ Human Gate 1 未通过。请先确认需求文档。"
    fi
    allow
fi

# 写入 implementation.md → implementer 角色 → 需要 HG-2 + 分支 + loop + 阶段顺序
if echo "$TARGET_FILE" | grep -q "implementation\.md$"; then
    if [ "$HG2" != "passed" ]; then
        deny "⛔ Human Gate 2 未通过。请先确认设计方案后再开始实施。"
    fi
    if [ "$LOOP_COUNT" -ge 2 ]; then
        deny "⛔ 实施循环已达上限（loop_count=$LOOP_COUNT >= 2）。请用户介入决定下一步。"
    fi
    validate_phase_id deny

    PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
    if [ ! -f "$PHASE_DIR/spec.md" ]; then
        deny "⛔ Phase spec 不存在。请确保 plan-generator 已创建 phases/$CURRENT_PHASE/spec.md。"
    fi
    # 阶段跳跃检测：必须有 repo-exploration.md
    check_stage_sequence "implementation" "$PHASE_DIR"
    # Git 分支校验
    EXPECTED_BRANCH="impl-${CURRENT_PHASE}"
    ACTUAL_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ] && [ "$ACTUAL_BRANCH" != "unknown" ]; then
        deny "⛔ Git 分支不匹配：当前 \`$ACTUAL_BRANCH\`，需要 \`$EXPECTED_BRANCH\`。请先创建/切换分支。"
    fi
    allow
fi

# 写入 review*.md → reviewer 角色 → 需要有效的 implementation.md + 阶段顺序
if echo "$TARGET_FILE" | grep -qE "review.*\.md$"; then
    if [ -n "$CURRENT_PHASE" ]; then
        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        # 阶段跳跃检测：implementation.md 必须有效
        check_stage_sequence "review" "$PHASE_DIR"
    fi
    validate_phase_id deny
    allow
fi

# 写入 verification.md → verifier 角色 → 需要有效的 review.md + 判决非 MUST-FIX + 阶段顺序
if echo "$TARGET_FILE" | grep -q "verification\.md$"; then
    if [ -n "$CURRENT_PHASE" ]; then
        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        # 阶段跳跃检测：review.md 必须有效且包含判决
        check_stage_sequence "verification" "$PHASE_DIR"
        # 额外检查：判决不能是 MUST-FIX
        REVIEW_FILE="$PHASE_DIR/review.md"
        if [ -f "$REVIEW_FILE" ]; then
            VERDICT=$(grep -oP '判决.*?\*\*\s*\K[^*]+' "$REVIEW_FILE" 2>/dev/null | head -1 | tr -d ' ')
            if [ "$VERDICT" = "MUST-FIX" ]; then
                deny "⛔ 审查判决为 MUST-FIX。请先修复后重新审查，不能跳过直接验证。"
            fi
        fi
    fi
    validate_phase_id deny
    allow
fi

# 写入 current-status.json → 严格校验完整流程
if echo "$TARGET_FILE" | grep -q "current-status\.json$"; then
    # 读取即将写入的新内容，检测是否在推进 HG-3 或切换 Phase
    NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_str // empty' 2>/dev/null)

    # 检查是否试图设置 hg3=passed
    if echo "$NEW_CONTENT" | grep -q '"hg3".*"passed"'; then
        if [ -n "$CURRENT_PHASE" ]; then
            PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
            # 必须有有效的 implementation.md
            if ! check_file_valid "$PHASE_DIR/implementation.md" 10 "##"; then
                deny "⛔ 流程不完整：尝试标记 HG-3 通过，但 implementation.md 不存在或内容无效。必须完成 implementer → reviewer → verifier 完整流程。"
            fi
            # 必须有有效的 review.md（含判决）
            if ! check_file_valid "$PHASE_DIR/review.md" 5 "判决"; then
                deny "⛔ 流程不完整：尝试标记 HG-3 通过，但 review.md 不存在或缺少「判决」。必须先完成 reviewer 审查。"
            fi
            # 必须有有效的 verification.md
            if ! check_file_valid "$PHASE_DIR/verification.md" 5; then
                deny "⛔ 流程不完整：尝试标记 HG-3 通过，但 verification.md 不存在。必须先完成 verifier 独立验证。"
            fi
            # review.md 判决不能是 MUST-FIX
            VERDICT=$(grep -oP '判决.*?\*\*\s*\K[^*]+' "$PHASE_DIR/review.md" 2>/dev/null | head -1 | tr -d ' ')
            if [ "$VERDICT" = "MUST-FIX" ]; then
                deny "⛔ 流程不完整：review.md 判决为 MUST-FIX，不能标记 HG-3 通过。请先修复并重新审查。"
            fi
        fi
    fi

    # 检查是否试图设置 hg2=passed（必须有 design.md + phase-plan.md）
    if echo "$NEW_CONTENT" | grep -q '"hg2".*"passed"'; then
        if ! check_file_valid "$SPEC_DIR/design.md" 10 "##"; then
            deny "⛔ 流程不完整：尝试标记 HG-2 通过，但 design.md 不存在或内容无效。"
        fi
        if ! check_file_valid "$SPEC_DIR/phase-plan.md" 10; then
            deny "⛔ 流程不完整：尝试标记 HG-2 通过，但 phase-plan.md 不存在。"
        fi
    fi

    # 检查是否试图设置 hg1=passed（必须有 requirements.md）
    if echo "$NEW_CONTENT" | grep -q '"hg1".*"passed"'; then
        if ! check_file_valid "$SPEC_DIR/requirements.md" 10 "##"; then
            deny "⛔ 流程不完整：尝试标记 HG-1 通过，但 requirements.md 不存在或内容无效。"
        fi
    fi

    # 检查是否在切换 current_phase（推进到下一Phase）
    if echo "$NEW_CONTENT" | grep -q '"current_phase"'; then
        # 如果有当前 Phase，检查当前 Phase 的流程是否全部完成
        if [ -n "$CURRENT_PHASE" ] && [ "$HG3" = "pending" ]; then
            PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
            if [ -f "$PHASE_DIR/implementation.md" ] && ! check_file_valid "$PHASE_DIR/verification.md" 5; then
                deny "⛔ 阶段跳跃：当前 Phase \`$CURRENT_PHASE\` 的 verifier 尚未完成，不能切换到下一个 Phase。完整流程：implementer → reviewer → verifier → HG-3 用户确认。"
            fi
        fi
    fi

    # HG 顺序校验提醒
    if [ "$HG1" = "pending" ] && [ "$HG2" = "pending" ]; then
        allow "⚠️ 注意：HG-1 和 HG-2 均为 pending。更新状态时请确保遵循顺序：HG-1 → HG-2 → HG-3。"
    fi
    allow
fi

# 默认放行
allow
