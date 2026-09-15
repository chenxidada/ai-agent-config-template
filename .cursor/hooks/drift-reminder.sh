#!/bin/bash
# ============================================
# drift-reminder.sh — 流程漂移提醒 · Cursor 版
# 绑定: subagentStop (failClosed:false)
# ============================================
# ── 这个 hook 存在的理由 ──
# 原 `pipeline-advance.sh`（v7，已删除）想做的是「子Agent 完成后引导下一步」，
# 但它：① 读不存在的 `.agent_name` 字段；② 用纯文本输出而非 `followup_message`。
# 两个协议错误叠加 → 从未生效。而 Cursor **确实支持**该能力：
#   subagentStop 输出 `{ "followup_message": "..." }` 可在子Agent 完成后自动续跑对话。
#
# ── 但它与 Human Gate 纪律有真实张力 ──
# 自动续跑会**主动对抗**「HG 必须停下等用户确认」这条铁律：
# 一条「下一步去派 implementer」的消息，会把该停下的节点推着往前走。
#
# ── 因此本 hook 的定位被刻意收窄 ──
#   ✅ 只在检测到**漂移/不一致**（某处该停没停、或产物与状态矛盾）时发一条**提醒**
#   ❌ 绝不引导「去做下一步」，绝不代替 Human Gate 做决定
# 消息内容恒定以「停下核对并向用户报告」结尾 —— 它是刹车，不是油门。
#
# ── 天然的防刷屏机制（不引入任何自建状态文件）──
#   payload 自带 `loop_count`（文档：该 subagentStop follow-up 已触发过的次数，从 0 开始）。
#   本 hook 只在 `loop_count < 1` 时发声 → **每个子Agent 最多提醒一次**。
#   这比自建 /tmp 标记或时间窗更可靠：状态由平台维护，无并发/清理问题。
#   （v7 的心跳文件就是因为「自建状态 + 无消费者」被删除的，不要重蹈。）
#
# ── 漂移检测项（全部只读，全部可被产物证实）──
#   D1 审查报告已产出但未合并：存在 review-*.md，但 review.md 缺失
#   D2 MUST-FIX 未回流：review 判决 MUST-FIX，但 loop_count 仍为 0
#   D3 原型门禁被绕过：UI Phase 的原型仍处「待确认」，却已出现审查/验证产物
#
# 输出契约（https://cursor.com/docs/agent/hooks，subagentStop）：
#   { "followup_message": "<自动续跑的消息>" } —— 仅在 status=completed 时被消费。
#   ⚠️ 本事件**不是** permission 型 hook：不要输出 permission/user_message，
#      也不要 source lib/emit.sh（那是给 allow/deny/ask 型事件用的）。
# ============================================

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"

# ── 读出 stdin（一次性）──
INPUT=$(cat 2>/dev/null || echo '{}')

# 静默退出 = 不注入 followup_message = 不干扰对话（本 hook 的绝大多数路径）
stay_silent() { exit 0; }

command -v jq >/dev/null 2>&1 || stay_silent

# ── 前置条件 1：只在子Agent 正常完成时提醒 ──
# 文档：followup_message「仅当 status 为 completed 时被消费」。其余状态输出也无意义。
STATUS=$(printf '%s' "$INPUT" | jq -r '.status // empty' 2>/dev/null)
[ "$STATUS" = "completed" ] || stay_silent

# ── 前置条件 2：防刷屏 —— 每个子Agent 只提醒一次 ──
LOOP=$(printf '%s' "$INPUT" | jq -r '.loop_count // 0' 2>/dev/null)
case "$LOOP" in
    ''|*[!0-9]*) LOOP=0 ;;
esac
[ "$LOOP" -lt 1 ] || stay_silent

# ── 前置条件 3：必须有活跃工作流，否则无从判断漂移 ──
ACTIVE_FILE="$PROJECT_ROOT/.specdev/active-workflow"
[ -f "$ACTIVE_FILE" ] || stay_silent

SLUG=$(head -1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
[ -n "$SLUG" ] || stay_silent

SPEC_DIR="$PROJECT_ROOT/.specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"
[ -f "$STATUS_FILE" ] || stay_silent

# ── 读取 current_phase（本 hook 刻意不 source status-read.sh）──
# 理由：status-read.sh 会校验 .human_gates/.current_stage 等必填字段，读失败即 return 1。
# 本 hook 是 fail-quiet 的提醒器，不是门禁 —— 状态不完整时应当闭嘴而非报错。
# 保持极简读取（单字段 + 兜底），避免把提醒器的失败面扩大到与门禁同级别。
PHASE=$(jq -r '.current_phase // empty' "$STATUS_FILE" 2>/dev/null)
[ -n "$PHASE" ] || stay_silent

PHASE_DIR="$SPEC_DIR/phases/$PHASE"
[ -d "$PHASE_DIR" ] || stay_silent

DRIFT=""

# ── D1：审查报告已产出但未合并 ──
# 4 个并行 reviewer 各自落盘 review-*.md，调度者负责合并成 review.md。
# 若原始报告在、合并件不在 → 合并这一步被漏掉了，下游（hg3 门禁 / verifier / KB 同步）
# 全部依赖 review.md，缺失会导致门禁判定失真。
if [ ! -f "$PHASE_DIR/review.md" ]; then
    _raw=$(find "$PHASE_DIR" -maxdepth 1 -name 'review-*.md' 2>/dev/null | wc -l | tr -d ' ')
    if [ "${_raw:-0}" -ge 1 ]; then
        DRIFT="审查报告已产出 ${_raw} 份（review-*.md），但合并件 review.md 不存在。"
    fi
fi

# ── D2：MUST-FIX 未回流 ──
# 审查判了 MUST-FIX 却不回流 implementer，是「审查白做了」的典型形态。
# loop_count 是调度者侧的回路计数（current-status.json），未自增即说明未回流。
if [ -z "$DRIFT" ] && [ -f "$PHASE_DIR/review.md" ]; then
    _loop_status=$(jq -r '.loop_count // 0' "$STATUS_FILE" 2>/dev/null)
    case "$_loop_status" in
        ''|*[!0-9]*) _loop_status=0 ;;
    esac
    if grep -qE '^##[[:space:]]*判决[：:][[:space:]]*MUST-FIX' "$PHASE_DIR/review.md" 2>/dev/null \
        && [ "$_loop_status" -eq 0 ]; then
        DRIFT="review.md 判决为 MUST-FIX，但 current-status.json 的 loop_count 仍为 0 —— 审查结论尚未回流给 implementer。"
    fi
fi

# ── D3：原型门禁被绕过 ──
# UI Phase 的正确顺序是：implementer 出原型 → 用户确认（.prototype-approved）→ 才允许派 reviewer/verifier。
# 若原型仍标「待确认」而已有审查/验证产物 → 门禁被绕过，视觉方向可能在未经确认的情况下被固化。
if [ -z "$DRIFT" ] && [ ! -f "$PHASE_DIR/.prototype-approved" ] \
    && [ -f "$PHASE_DIR/implementation.md" ] \
    && grep -q '## Prototype（待确认）' "$PHASE_DIR/implementation.md" 2>/dev/null; then
    _downstream=$(find "$PHASE_DIR" -maxdepth 1 \( -name 'review-*.md' -o -name 'review.md' -o -name 'verification.md' \) 2>/dev/null | wc -l | tr -d ' ')
    if [ "${_downstream:-0}" -ge 1 ]; then
        DRIFT="UI Phase 的原型仍处「待确认」状态，但已存在审查/验证产物（${_downstream} 份）—— 原型确认门禁被绕过。"
    fi
fi

[ -n "$DRIFT" ] || stay_silent

# ── 输出：一条只含提醒的 followup_message ──
# 措辞要求（改这句话前请先读文件头的定位说明）：
#   1) 明确「不要据此推进」——它是刹车；
#   2) 明确「停下向用户报告」——把决定权交回用户；
#   3) 不复述下一步该委托谁（那会变成事实上的推进指令）。
MSG="⚠️ 流程漂移提醒（仅提醒，请勿据此推进流程）：${DRIFT}
请停下核对：读取 \`.specdev/specs/${SLUG}/current-status.json\` 与 \`phases/${PHASE}/\` 下的实际产物，确认真实进度后向用户报告并等待指示。
不要跳过任何 Human Gate，也不要自行判定某步骤「已完成」或「可以继续」。"
MSG="$MSG
（本条为自动漂移提醒 ${SLUG}/${PHASE}；每个子Agent 最多提醒一次。若判断为误报，请向用户说明后继续。）"

jq -nc --arg m "$MSG" '{followup_message:$m}' 2>/dev/null || echo '{}'
exit 0
