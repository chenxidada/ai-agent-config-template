#!/bin/bash
# ============================================
# post-tool-drift.sh — 块 A 第一段：命令执行后漂移计数 + 软熔断注入
# ============================================
# 绑定: PostToolUse (matcher: RunCommand)
# 协议: stdin JSON(含 tool_name/tool_input/tool_response/session_id) → stdout JSON
#       达阈时输出 decision:block + hookSpecificOutput.additionalContext 注入根因指引。
#
# 职责（design §块A两段式协作流程 L184-192）:
#   tool_name != RunCommand            → exit 0（双重过滤，不干预）
#   从 tool_response 多候选提取 exit + err（HYPOTHESIS 字段路径兜底，design §42）
#   exit 无法判定（全落空）             → AC-A7 保守分支，不计数 exit 0
#   exit == 0（成功）                   → reset_counter，exit 0（AC-A6）
#   exit != 0 但非构建/测试类           → 不计数 exit 0（Q-A）
#   exit != 0 且构建/测试类             → compute_fingerprint + bump_or_reset(exit,fp,SID)（AC-A2/A3）
#   count >= DRIFT_THRESHOLD(3)         → decision:block + additionalContext 注入（AC-A4/A8）
#
# ⚠️ 本 hook 只计数 + 软注入，绝不硬杀命令（命令在 PostToolUse 时已执行完毕）。
#    真正的「拦下一次同类命令」由 PreToolUse(pipeline-gate.sh 块A第二段) 用 ask 完成。
# ============================================

set -euo pipefail

# ── source 共享库（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/drift-lib.sh
source "$HOOK_DIR/lib/drift-lib.sh"

INPUT=$(cat 2>/dev/null || echo '{}')

# ── 双重过滤：matcher 已限 RunCommand，脚本内再判一次（防误配 / 手工调用）──
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
[ "$TOOL_NAME" = "RunCommand" ] || exit 0

# ── probe（首步实测）：dump 一次 tool_response 结构，供字段路径确认/调试 ──
# 无副作用（写 /tmp），失败静默；确认字段后可删。
echo "$INPUT" | jq -c '.tool_response // {}' > /tmp/.trae-drift-probe.json 2>/dev/null || true

# ── 提取命令串（tool_input.command 主，cmd 兜底）──
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input.cmd // empty' 2>/dev/null || echo "")

# ── 提取 session_id（HYPOTHESIS 多候选路径兜底，比照退出码/错误输出的多候选风格）──
# 顺序：session_id → sessionId(camelCase) → session → conversation_id → conversationId；
# 全落空 → SID 为空。SID 仅用于多会话隔离（加分项）；缺 SID 时 bump_or_reset 会降级为
# fingerprint-only 计数（SF-1 修复），保证即使拿不到 session_id 熔断仍能工作。
# ⚠️ 真实 PostToolUse stdin 的 session_id 字段名仍是 HYPOTHESIS，待用户真实环境实测确认；
#    多候选 + 缺 SID 降级是双重兜底。
SID=$(echo "$INPUT" | jq -r '.session_id // .sessionId // .session // .conversation_id // .conversationId // ""' 2>/dev/null || echo "")

# ── 提取退出码（HYPOTHESIS 多候选路径兜底，design §42）──
# 顺序：exit_code → exitCode → code → status；全落空 → EXIT 为空。
EXIT=$(echo "$INPUT" | jq -r '.tool_response.exit_code // .tool_response.exitCode // .tool_response.code // .tool_response.status // empty' 2>/dev/null || echo "")

# ── AC-A7 保守分支：退出码无法判定（全候选落空）→ 不计数、不熔断 ──
if [ -z "$EXIT" ]; then
    exit 0
fi

# ── 退出码 0（成功）→ 清零计数（AC-A6）──
if [ "$EXIT" = "0" ]; then
    reset_counter || true
    exit 0
fi

# ── 非构建/测试类命令 → 不计数（Q-A，grep/test/diff 等正常非零不污染计数）──
if ! is_build_test_cmd "$CMD"; then
    exit 0
fi

# ── 提取错误输出（HYPOTHESIS 多候选：stderr → output → stdout → 整体 tostring）──
ERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // .tool_response.output // .tool_response.stdout // (.tool_response|tostring)' 2>/dev/null || echo "")

# ── 计算失败指纹（AC-A2）。不可判定 → AC-A7 保守分支，不计数 ──
FP=""
if FP_OUT=$(compute_fingerprint "$ERR"); then
    FP="$FP_OUT"
else
    # compute_fingerprint 回显 __DRIFT_FP_UNDECIDABLE__ 且 return 1 → 无法可靠归类
    exit 0
fi

# ── 计数：同 session + 同指纹累加 / 异类重置为 1（AC-A3/A6）──
# bump_or_reset 内部会导出 DC_COUNT；此处 || true 兜底 set -e。
if ! bump_or_reset "$EXIT" "$FP" "$SID"; then
    # 写计数失败（罕见 IO 错误）→ 保守放行，不熔断
    exit 0
fi

# ── 读回最新计数（bump_or_reset 已导出 DC_COUNT，再 read 一次确保准确）──
read_counter || true

# ── 达阈值 → 软熔断：注入根因指引（AC-A4/A8）──
if [ "${DC_COUNT:-0}" -ge "$DRIFT_THRESHOLD" ]; then
    # SF-3：根因文案统一来自 drift-lib.sh 的 root_cause_guidance()（单一维护点）
    GUIDANCE=$(root_cause_guidance "$DC_COUNT" "$DRIFT_THRESHOLD" "$CMD")

    if OUT=$(jq -cn --arg g "$GUIDANCE" '{
        decision: "block",
        reason: $g,
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $g
        }
    }' 2>/dev/null); then
        printf '%s\n' "$OUT"
    fi
    exit 0
fi

exit 0
