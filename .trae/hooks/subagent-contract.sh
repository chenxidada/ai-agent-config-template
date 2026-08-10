#!/bin/bash
# ============================================
# subagent-contract.sh — 块 B：子 agent 产出契约校验
# ============================================
# 绑定: SubagentStop（独立事件键，绝不绑定 Trae Stop —— AC-B1 硬约束）
# 协议: stdin JSON(通用字段 session_id/cwd/hook_event_name/workspace_roots，
#       [?agent 标识 = HYPOTHESIS]) → stdout JSON
#       有缺失/无效期望产出 → decision:block + reason（回灌为新 query 提示调度者重派）。
#
# 职责（design §块B流程 L48-51 + repo-exploration §4 路径 A）:
#   1. probe 首步实测：dump 真实 SubagentStop stdin 到 /tmp/.trae-drift-probe-subagent.json
#      （确认①事件是否真触发 ②stdin 是否带 agent/task 标识 ③block 是否误阻子 agent 停止）
#   2. 主方案（AC-B6 登记式兜底，不依赖 agent 标识）：
#      scan_missing_expected(SID) 扫「checked=false 且 drift_file_valid 失败(缺失/空)」条目 → 收集
#   3. AC-B4 结构标记校验：对「存在且非空」但缺 `##` 章节的期望产出，标记「内容明显不对路」
#      （一律复用 drift_file_valid，min_lines + marker；AC-B7 禁第二套逻辑）
#   4. 校验后对每条已报条目 mark_checked 回写 checked=true（避免同一缺失重复报）
#   5. 有缺失/无效 → decision:block + reason；无 → exit 0（AC-B6 不误报）
#
# ⚠️ block 语义风险（R5, HYPOTHESIS）：SubagentStop 的 block 阻断的是「子 agent 停止」
#    还是「回灌给主调度者」尚未实测。本 hook 同时输出 reason + additionalContext——
#    若 block 表现为软提示则 additionalContext 兜底；若实测发现 block 误阻子 agent 正常
#    停止，应改为 exit 0（去掉 decision:block，只留 additionalContext）。见 implementation.md。
# ============================================

set -euo pipefail

# ── source 共享库（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/drift-lib.sh
source "$HOOK_DIR/lib/drift-lib.sh"

INPUT=$(cat 2>/dev/null || echo '{}')

# ── probe（首步实测，repo-exploration 强制）：dump 一次真实 SubagentStop stdin ──
# 无副作用（写 /tmp），失败静默。用于确认事件是否触发、stdin 是否带 agent/task 标识、
# block 是否误阻子 agent 停止。确认后可删。
printf '%s' "$INPUT" | jq -c '.' > /tmp/.trae-drift-probe-subagent.json 2>/dev/null || true

# ── 读通用字段（照 pipeline-advance.sh / post-tool-drift.sh 范式）──
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // .sessionId // .session // ""' 2>/dev/null || echo "")

# ── AC-B5 增强侦测（HYPOTHESIS）：若 stdin 确带 agent/task 标识则记录（多候选兜底）──
# 主方案不依赖它；仅探测记录，供后续实测确认是否可叠加精确校验路径。
AGENT_HINT=$(printf '%s' "$INPUT" | jq -r '.agent_name // .agentName // .agent_id // .agent // .subagent // .task // ""' 2>/dev/null || echo "")
[ -n "$AGENT_HINT" ] && printf '%s\n' "$AGENT_HINT" > /tmp/.trae-drift-probe-subagent-agent.txt 2>/dev/null || true

# ── cd 到工作区（期望产出为绝对路径，cd 主要为兜底；失败静默）──
cd "$CWD" 2>/dev/null || true

# ── 收集缺失/无效条目 ──
# REASON_LINES 累积每条问题描述；MARK_TARGETS 累积需 mark_checked 的 expected 路径。
REASON_LINES=""
MARK_TARGETS=""
HAS_ISSUE=0

# ── 主方案（AC-B3/B6）：scan_missing_expected 回显 checked=false 且缺失/空 的条目 ──
# scan 返回 0 = 找到缺失（bash 成功语义）；返回 1 = 无缺失/无清单。必须 if 包裹。
MISSING_OUT=""
if MISSING_OUT=$(scan_missing_expected "$SID"); then
    # 逐行解析缺失条目
    while IFS= read -r mrow; do
        [ -z "$mrow" ] && continue
        m_agent=$(printf '%s' "$mrow" | jq -r '.agent // "?"' 2>/dev/null || echo "?")
        m_expected=$(printf '%s' "$mrow" | jq -r '.expected // ""' 2>/dev/null || echo "")
        [ -z "$m_expected" ] && continue
        REASON_LINES="${REASON_LINES}  - [缺失/空] 子 agent「${m_agent}」期望产出未生成或为空：${m_expected}"$'\n'
        MARK_TARGETS="${MARK_TARGETS}${m_expected}"$'\n'
        HAS_ISSUE=1
    done <<< "$MISSING_OUT"
fi

# ── AC-B4 结构标记校验：对「存在且非空」但缺 `##` 章节的期望产出标记「内容不对路」──
# 独立遍历 jsonl checked=false 条目；只处理「drift_file_valid(1) 通过（即上面 scan 未报）」
# 但「drift_file_valid(3,'##') 失败」的条目 → 与 scan 结果零重叠。一律复用 drift_file_valid。
if [ -f "$DRIFT_EXPECTED_FILE" ]; then
    while IFS= read -r row; do
        [ -z "$row" ] && continue
        if ! printf '%s' "$row" | jq empty 2>/dev/null; then
            continue
        fi
        r_sid=$(printf '%s' "$row" | jq -r '.session_id // ""' 2>/dev/null || echo "")
        if [ -n "$SID" ] && [ "$r_sid" != "$SID" ]; then
            continue
        fi
        r_checked=$(printf '%s' "$row" | jq -r '.checked // false' 2>/dev/null || echo "false")
        [ "$r_checked" = "true" ] && continue
        r_agent=$(printf '%s' "$row" | jq -r '.agent // "?"' 2>/dev/null || echo "?")
        r_expected=$(printf '%s' "$row" | jq -r '.expected // ""' 2>/dev/null || echo "")
        [ -z "$r_expected" ] && continue
        # 存在且非空（scan 未报）→ 进一步查结构标记；缺失/空的已被 scan 覆盖，跳过避免重复
        if drift_file_valid "$r_expected" 1; then
            if ! drift_file_valid "$r_expected" 3 "##"; then
                REASON_LINES="${REASON_LINES}  - [内容不对路] 子 agent「${r_agent}」产出缺必要结构标记（无 ## 章节或过短）：${r_expected}"$'\n'
                MARK_TARGETS="${MARK_TARGETS}${r_expected}"$'\n'
                HAS_ISSUE=1
            fi
        fi
    done < "$DRIFT_EXPECTED_FILE"
fi

# ── 无问题 → 静默放行（AC-B6 不误报：无清单/无缺失/无标识均不干预）──
if [ "$HAS_ISSUE" -eq 0 ]; then
    exit 0
fi

# ── 有问题 → 逐条 mark_checked 回写，避免下次 SubagentStop 重复报（AC-B6 回写）──
while IFS= read -r tgt; do
    [ -z "$tgt" ] && continue
    mark_checked "$SID" "$tgt" || true
done <<< "$MARK_TARGETS"

# ── 组装 reason（提示调度者疑似跑偏需重派 / 人工介入）──
REASON="🛑 子 agent 产出契约校验未通过：以下约定产出文件缺失或内容明显不对路——
${REASON_LINES}
疑似子 agent 跑偏。请调度者据此重新派发对应子 agent，或人工介入确认。
（本校验依赖调度者派发前用 register_expected 登记期望产出；若清单未登记则不校验。）"

# ── decision:block + reason（回灌为新 query）；additionalContext 兜底软提示（R5 双保险）──
if OUT=$(jq -cn --arg r "$REASON" '{
    decision: "block",
    reason: $r,
    hookSpecificOutput: {
        hookEventName: "SubagentStop",
        additionalContext: $r
    }
}' 2>/dev/null); then
    printf '%s\n' "$OUT"
fi
exit 0
