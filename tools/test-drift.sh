#!/bin/bash
# ============================================================
# test-drift.sh — drift-reminder.sh 行为测试
# ============================================================
# 为什么需要：这个 hook 的输出会**自动续跑对话**（followup_message），
# 是本项目里唯一能主动影响对话流的 hook。它必须在两件事上被证明：
#   ① 该闭嘴时闭嘴（无漂移 / 非正常完成 / 已提醒过 → 一个字都不输出）
#   ② 发声时必须只是「刹车」而非「油门」（消息里不得出现推进指令）
# 第 ② 条是用户明确决策的契约：「只发提醒、绝不自动推进」。
#
# 依据：Cursor 官方文档 subagentStop 的 Output 仅 `followup_message`，
#       且「Only consumed when status is completed」。
#
# 用法：bash tools/test-drift.sh
# ============================================================
cd "$(dirname "$0")/.." || exit 1
HOOK=".cursor/hooks/drift-reminder.sh"

pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

SB=$(mktemp -d)
HOOKDIR="$SB/.cursor/hooks"
mkdir -p "$HOOKDIR" "$SB/.specdev/specs/demo/phases/phase-1"
cp "$HOOK" "$HOOKDIR/drift-reminder.sh"
PHASE_DIR="$SB/.specdev/specs/demo/phases/phase-1"
STATUS_FILE="$SB/.specdev/specs/demo/current-status.json"
printf 'demo\n' > "$SB/.specdev/active-workflow"

write_status() { # write_status <loop_count>
    cat > "$STATUS_FILE" <<EOF
{"slug":"demo","current_stage":"phase-implementation","current_phase":"phase-1","loop_count":$1,
 "human_gates":{"hg1":"passed","hg2":"passed","hg3":"pending"}}
EOF
}

payload() { # payload [status] [loop_count]
    jq -nc --arg s "${1:-completed}" --argjson l "${2:-0}" \
        '{subagent_type:"implementer",status:$s,task:"x",loop_count:$l,modified_files:[]}'
}

run() { # run <payload> → stdout
    printf '%s' "$1" | bash "$HOOKDIR/drift-reminder.sh" 2>/dev/null
}

# 断言「完全静默」（空输出，或合法 JSON 但无 followup_message）
expect_silent() { # expect_silent <payload> <用例名>
    local out; out=$(run "$1")
    if [ -z "$out" ] || ! printf '%s' "$out" | jq -e '.followup_message' >/dev/null 2>&1; then
        ok "$2"
    else
        bad "$2 → 不该发声却输出了 followup_message"
    fi
}

# 断言「发声」
expect_speak() { # expect_speak <payload> <用例名>
    local out; out=$(run "$1")
    if printf '%s' "$out" | jq -e '.followup_message' >/dev/null 2>&1; then
        ok "$2"
    else
        bad "$2 → 期望 followup_message，实际静默"
    fi
}

echo "── 1. 该闭嘴时闭嘴 ──"
write_status 0; clean_phase_dir() { rm -f "$PHASE_DIR"/review*.md "$PHASE_DIR"/verification.md "$PHASE_DIR"/implementation.md "$PHASE_DIR"/.prototype-approved; }
clean_phase_dir
expect_silent "$(payload)" "无漂流迹象 → 静默（不干扰对话）"

write_status 0
expect_silent "$(payload error 0)" "status=error → 静默（该字段本就不被消费）"
expect_silent "$(payload aborted 0)" "status=aborted → 静默"

printf '# 审查报告\n\n## 判决：PASS\n' > "$PHASE_DIR/review.md"
expect_silent "$(payload completed 1)" "loop_count>=1 → 静默（每个子Agent 最多提醒一次）"
expect_silent "$(payload completed 3)" "loop_count=3 → 静默"

mv "$SB/.specdev/active-workflow" "$SB/.specdev/aw.bak"
expect_silent "$(payload completed 0)" "无活跃工作流 → 静默"
mv "$SB/.specdev/aw.bak" "$SB/.specdev/active-workflow"

write_status 0
mv "$STATUS_FILE" "$STATUS_FILE.bak"
expect_silent "$(payload completed 0)" "状态文件不存在 → 静默（提醒器不是门禁，不报错）"
mv "$STATUS_FILE.bak" "$STATUS_FILE"

printf '{"slug":"demo","current_stage":"requirement-analysis","current_phase":"","human_gates":{"hg1":"pending","hg2":"pending","hg3":"pending"}}' > "$STATUS_FILE"
expect_silent "$(payload completed 0)" "无 current_phase（尚未进入 Phase）→ 静默"

echo "── 2. D1 审查报告已产出但未合并 ──"
write_status 0; clean_phase_dir
printf '# impl\n\n## 变更\n- a\n' > "$PHASE_DIR/implementation.md"
printf '# reviewer 1\n\n## Must-Fix 汇总\n（无）\n' > "$PHASE_DIR/review-correctness.md"
expect_speak "$(payload)" "有 review-*.md 但无 review.md → 发声"

out=$(run "$(payload)")
if printf '%s' "$out" | jq -r '.followup_message' | grep -qF 'review.md'; then
    ok "提醒内容点名了具体的缺失产物（可核对，非泛泛而谈）"
else
    bad "提醒内容未说明缺什么"
fi

echo "── 3. D2 MUST-FIX 未回流 ──"
write_status 0; clean_phase_dir
printf '# impl\n\n## 变更\n- a\n' > "$PHASE_DIR/implementation.md"
printf '# 审查报告（合并）\n\n## 判决：MUST-FIX\n\n## Must-Fix 汇总\n- 🔴 边界未处理\n' > "$PHASE_DIR/review.md"
expect_speak "$(payload)" "判决 MUST-FIX 但 loop_count 仍为 0 → 发声"

write_status 1
expect_silent "$(payload)" "MUST-FIX 且 loop_count=1（已回流）→ 静默"

echo "── 4. D3 原型确认门禁被绕过 ──"
write_status 0; clean_phase_dir
printf '# Impl\n\n## Prototype（待确认）\n\n### 截图\n- desktop.png\n' > "$PHASE_DIR/implementation.md"
expect_silent "$(payload)" "原型待确认、无下游产物 → 静默（这是正常的中途状态）"
printf '# reviewer 1\n\n## Must-Fix 汇总\n（无）\n' > "$PHASE_DIR/review-correctness.md"
printf '# 审查报告（合并）\n\n## 判决：PASS\n' > "$PHASE_DIR/review.md"
expect_speak "$(payload)" "原型待确认却已派发 reviewer → 发声"
touch "$PHASE_DIR/.prototype-approved"
rm -f "$PHASE_DIR/review-correctness.md"
expect_silent "$(payload)" "原型已确认（.prototype-approved 在）→ 静默"

echo "── 5. 输出契约：只能是「刹车」不能是「油门」──"
write_status 0; clean_phase_dir
printf '# impl\n\n## 变更\n- a\n' > "$PHASE_DIR/implementation.md"
printf '# reviewer 1\n' > "$PHASE_DIR/review-correctness.md"
OUT=$(run "$(payload)")
# 5.1 只含文档定义的字段
KEYS=$(printf '%s' "$OUT" | jq -r 'keys | join(",")' 2>/dev/null)
if [ "$KEYS" = "followup_message" ]; then
    ok "输出只含 followup_message（未混入 permission/user_message 等 permission 型字段）"
else
    bad "输出字段异常: $KEYS"
fi
# 5.2 必须含「停下 / 报告用户」类刹车语义
MSG=$(printf '%s' "$OUT" | jq -r '.followup_message' 2>/dev/null)
printf '%s' "$MSG" | grep -q '请勿据此推进' && ok "消息显式声明「请勿据此推进流程」" || bad "消息缺少「请勿据此推进」声明"
printf '%s' "$MSG" | grep -q '停下核对'     && ok "消息要求「停下核对」" || bad "消息缺少「停下核对」"
printf '%s' "$MSG" | grep -q '向用户报告'   && ok "消息要求「向用户报告」" || bad "消息缺少「向用户报告」"
printf '%s' "$MSG" | grep -q 'Human Gate'  && ok "消息重申不得跳过 Human Gate" || bad "消息未重申 Human Gate 纪律"
# 5.3 反向断言：不得出现任何「自动推进」式指令
if printf '%s' "$MSG" | grep -qE '接下来(应该|请)?(委托|派发|执行)|请(继续|接着)(委托|派发|执行|推进)|下一步请'; then
    bad "消息里出现了推进型指令（违反「只提醒不推进」决策）: $MSG"
else
    ok "消息不含任何推进型指令（未对抗 Human Gate 纪律）"
fi
# 5.4 不得出现 permission 型字段
if printf '%s' "$OUT" | grep -qE '"permission"'; then
    bad "输出里出现了 permission 字段（subagentStop 非 permission 型事件）"
else
    ok "无 permission 字段"
fi

rm -rf "$SB"
printf '\n结果：%d 通过 / %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
