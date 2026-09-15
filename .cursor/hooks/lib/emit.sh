#!/bin/bash
# ============================================
# lib/emit.sh — hook 输出原语（sourced，非独立执行）
# ============================================
# 为什么存在：此前 gate 内有 26 处手写 JSON 字面量（含 `cat <<'BLOCK'` heredoc），
# 是本项目最大的单一漂移点。手写 JSON 有两个后果：
#   1) 消息里含未转义的 " 或换行 → 产出非法 JSON；
#   2) 本 hook 配置为 failClosed:true，非法 JSON 表现为「hook 崩溃」黑盒报错，
#      真正想传达的拦截原因完全丢失，且无法自查。
# 所有输出一律经 jq 构造（--arg 自动转义），jq 不可用时降级为最小合法 JSON。
#
# ── 事件 × permission 支持矩阵（依据 https://cursor.com/docs/hooks）──
#   preToolUse            allow | deny        ← ask 被接受但【不执行】，等同 allow
#   subagentStart         allow | deny        ← ask 按 deny 处理
#   beforeShellExecution  allow | deny | ask  ← ask 真实生效（弹窗由用户批准）
#   beforeMCPExecution    allow | deny | ask
#   subagentStop          —（本 hook 输出 followup_message，非 permission）
#
# ⚠️ 铁律：不得在未支持 ask 的事件上使用 emit_ask。
#    「字段被接受但不执行」比「字段不存在」更危险 —— 门禁会静默失效而无人察觉。
#    判据：hg3 的写入门槛是 Write/Edit（preToolUse），在该事件上唯一可用原语是 allow/deny。
# ============================================

# ── 允许 ──
emit_allow() {
    jq -nc '{permission:"allow"}' 2>/dev/null || printf '{"permission":"allow"}\n'
    exit 0
}

# ── 允许 + 向 Agent 附一条说明 ──
emit_allow_msg() {
    jq -nc --arg m "${1:-}" '{permission:"allow",agent_message:$m}' 2>/dev/null \
        || printf '{"permission":"allow"}\n'
    exit 0
}

# ── 拒绝（user_message 给用户看，agent_message 给 Agent 看，缺省同 user_message）──
emit_deny() {
    jq -nc --arg u "${1:-}" --arg a "${2:-${1:-}}" \
        '{permission:"deny",user_message:$u,agent_message:$a}' 2>/dev/null \
        || printf '{"permission":"deny"}\n'
    exit 0
}

# ── 征询用户批准 ⚠️ 仅 beforeShellExecution / beforeMCPExecution 可用 ──
# 若在 preToolUse 上调用，等价于放行 —— 宁可 deny，不可假装在拦。
emit_ask() {
    jq -nc --arg u "${1:-}" --arg a "${2:-${1:-}}" \
        '{permission:"ask",user_message:$u,agent_message:$a}' 2>/dev/null \
        || printf '{"permission":"deny"}\n'
    exit 0
}
