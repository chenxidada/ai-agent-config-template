#!/bin/bash
# ============================================
# pipeline-gate.sh — Human Gate 程序化门禁 (Trae 版)
# 绑定: PreToolUse (matcher: Write|Edit|RunCommand)
# schema: .specdev/specs/{slug}/current-status.json
#
# 关键适配：Trae 中 Subagent 由 SOLO Agent 自动路由，
# 没有显式的 "Task" 工具。因此拦截策略改为：
# 1. 拦截 RunCommand 中的危险命令和 git commit/push
# 2. 拦截对 .specdev/specs/ 下关键文件的写入（按文件路径推断操作的Agent）
# 3. 拦截 implementer 在错误 git 分支上的写操作
#
# 协议: stdin JSON → stdout 文本(注入给Agent) + 退出码(0=allow, 非0=deny)
# ============================================

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)

cd "$CWD" 2>/dev/null || true

# ── 辅助函数：拒绝（非零退出码 = Trae deny） ──
deny() {
    echo "$1"
    exit 1
}

# ── 辅助函数：允许 ──
allow() {
    echo "${1:-}"
    exit 0
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
CURRENT_PHASE=$(jq -r '.current_phase // ""' "$STATUS_FILE" 2>/dev/null)
LOOP_COUNT=$(jq -r '.loop_count // 0' "$STATUS_FILE" 2>/dev/null)

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

# ── 按目标文件路径推断操作类型并校验 ──

# 写入 design.md / phase-plan.md → plan-generator 角色 → 需要 HG-1 已过
if echo "$TARGET_FILE" | grep -qE "(design\.md|phase-plan\.md)$"; then
    if [ "$HG1" != "passed" ]; then
        deny "⛔ Human Gate 1 未通过。请先确认需求文档后再进入设计阶段。"
    fi
    allow
fi

# 写入 requirements.md → requirement-analyst 角色 → 无前置条件，放行
if echo "$TARGET_FILE" | grep -q "requirements\.md$"; then
    allow
fi

# 写入 repo-exploration.md → code-explorer 角色 → 仅警告 Phase ID
if echo "$TARGET_FILE" | grep -q "repo-exploration"; then
    validate_phase_id warn
    allow
fi

# 写入 implementation.md → implementer 角色 → 需要 HG-2 + 分支 + loop
if echo "$TARGET_FILE" | grep -q "implementation\.md$"; then
    if [ "$HG2" != "passed" ]; then
        deny "⛔ Human Gate 2 未通过。请先确认设计方案后再开始实施。"
    fi
    if [ "$LOOP_COUNT" -ge 2 ]; then
        deny "⛔ 实施循环已达上限（loop_count=$LOOP_COUNT >= 2）。请用户介入。"
    fi
    validate_phase_id deny
    if [ ! -f "$SPEC_DIR/phases/$CURRENT_PHASE/spec.md" ]; then
        deny "⛔ Phase spec 不存在。请确保 plan-generator 已创建 phases/$CURRENT_PHASE/spec.md。"
    fi
    # Git 分支校验
    EXPECTED_BRANCH="impl-${CURRENT_PHASE}"
    ACTUAL_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ] && [ "$ACTUAL_BRANCH" != "unknown" ]; then
        deny "⛔ Git 分支不匹配：当前 \`$ACTUAL_BRANCH\`，需要 \`$EXPECTED_BRANCH\`。请先创建/切换分支。"
    fi
    allow
fi

# 写入 review*.md → reviewer 角色 → 需要 implementation.md 存在
if echo "$TARGET_FILE" | grep -qE "review.*\.md$"; then
    if [ -n "$CURRENT_PHASE" ]; then
        IMPL_FILE="$SPEC_DIR/phases/$CURRENT_PHASE/implementation.md"
        if [ ! -s "$IMPL_FILE" ]; then
            deny "⛔ 无 implementation.md。请先完成实施。"
        fi
    fi
    validate_phase_id deny
    allow
fi

# 写入 verification.md → verifier 角色 → 需要 review.md 存在且判决非 MUST-FIX
if echo "$TARGET_FILE" | grep -q "verification\.md$"; then
    if [ -n "$CURRENT_PHASE" ]; then
        REVIEW_FILE="$SPEC_DIR/phases/$CURRENT_PHASE/review.md"
        if [ ! -s "$REVIEW_FILE" ]; then
            deny "⛔ 无 review.md。请先完成代码审查。"
        fi
        VERDICT=$(grep -oP '判决.*?\*\*\s*\K[^*]+' "$REVIEW_FILE" 2>/dev/null | head -1 | tr -d ' ')
        if [ "$VERDICT" = "MUST-FIX" ]; then
            deny "⛔ 审查判决为 MUST-FIX。请先修复后重新审查。"
        fi
    fi
    validate_phase_id deny
    allow
fi

# 默认放行
allow
