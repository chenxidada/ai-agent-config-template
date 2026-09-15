#!/bin/bash
# ============================================================
# test-hook-contract.sh — hook 输出契约测试
# ============================================================
# 为什么需要（本文件存在的理由）：
#   本项目最危险的一类 bug 不是「崩溃」，而是**「输出字段名写错」**——
#   hook 照常 exit 0、日志一切正常，但字段从未被消费，整条链路**静默失效**。
#   session-recovery.sh 就因为把注入字段写成 Claude Code 的
#   `hookSpecificOutput.additionalContext`（camelCase）而非 Cursor 文档的
#   `additional_context`（snake_case），导致「压缩/新会话恢复注入」自建立起从未生效。
#   单元测试测不出这种错 —— 只有「事件 × 允许字段」的契约断言能测出来。
#
# 依据：https://cursor.com/docs/agent/hooks（各事件 Output 表）。
#   事件              允许的输出字段
#   preToolUse        permission / user_message / agent_message / updated_input
#                     ⚠️ ask 被接受但**不执行**（文档原文），故断言中禁止出现 ask
#   beforeShellExecution  permission(allow|deny|ask) / user_message / agent_message
#   sessionStart      env / additional_context          ← 无 hookSpecificOutput / camelCase
#   preCompact        user_message
#   subagentStop      followup_message
#
# ⚠️ 本测试必然无法覆盖「字段名对但值语义错」，那由 test-gate.sh 覆盖。
# ============================================================
cd "$(dirname "$0")/.." || exit 1

pass=0; fail=0
ok()   { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

# assert_keys <JSON> <用例名> <允许字段的空格分隔列表>
assert_keys() {
    local json="$1" name="$2" allow="$3" k bad_keys=""
    [ -z "$json" ] && { bad "$name：输出为空"; return; }
    if ! printf '%s' "$json" | jq -e . >/dev/null 2>&1; then
        bad "$name：输出不是合法 JSON"; return
    fi
    while IFS= read -r k; do
        [ -z "$k" ] && continue
        case " $allow " in
            *" $k "*) ;;
            *) bad_keys="$bad_keys $k" ;;
        esac
    done < <(printf '%s' "$json" | jq -r 'keys[]' 2>/dev/null)
    if [ -n "$bad_keys" ]; then
        bad "$name：出现文档未定义的输出字段 →$bad_keys"
    else
        ok "$name"
    fi
}

# ── 沙箱：构造一个可读的活跃工作流 ──
SB=$(mktemp -d)
mkdir -p "$SB/.cursor/hooks" "$SB/.specdev/specs/demo"
cp -r .cursor/hooks/lib "$SB/.cursor/hooks/"
cp .cursor/hooks/session-recovery.sh .cursor/hooks/context-snapshot.sh "$SB/.cursor/hooks/"
printf 'demo\n' > "$SB/.specdev/active-workflow"
cat > "$SB/.specdev/specs/demo/current-status.json" <<'EOF'
{"slug":"demo","description":"契约测试","current_stage":"phase-implementation","current_phase":"phase-1",
 "loop_count":0,"human_gates":{"hg1":"passed","hg2":"passed","hg3":"pending"},
 "phases":{"phase-1":{"implementer":"completed","reviewer":"pending","verifier":"pending"}}}
EOF

echo "── sessionStart / session-recovery.sh ──"
OUT=$(echo '{"session_id":"x"}' | bash "$SB/.cursor/hooks/session-recovery.sh" 2>/dev/null)
assert_keys "$OUT" "输出只含文档定义字段 (env/additional_context)" "env additional_context"
if printf '%s' "$OUT" | jq -e '.additional_context' >/dev/null 2>&1; then
    ok "恢复上下文真的写在 additional_context 里（而非 camelCase）"
else
    bad "additional_context 缺失 —— 注入会静默失效（这正是本测试要防的 bug）"
fi
# 反向断言：不得再出现 Claude Code 的 camelCase 形态
if printf '%s' "$OUT" | rg -q 'additionalContext|hookSpecificOutput' 2>/dev/null; then
    bad "仍存在 camelCase 字段（additionalContext / hookSpecificOutput）"
else
    ok "无 Claude Code camelCase 残留"
fi
# 内容断言：锚定块是压缩/新会话后唯一存活的信息面，必须覆盖 UI 工作流的两个停止点。
# （漂移已真实发生过：规则侧升级到 4 个 HG 后，锚定块仍写「三个节点」且不提原型门禁。）
for kw in "HG-1.5" "原型确认"; do
    if printf '%s' "$OUT" | rg -q "$kw" 2>/dev/null; then
        ok "锚定块覆盖 UI 停止点：$kw"
    else
        bad "锚定块缺少「$kw」—— 恢复后最容易跳过的就是 UI 的两个 Gate"
    fi
done

echo "── preCompact / context-snapshot.sh（观察型，只允许 user_message）──"
OUT=$(echo '{"trigger":"auto"}' | bash "$SB/.cursor/hooks/context-snapshot.sh" 2>/dev/null)
assert_keys "$OUT" "输出只含文档定义字段 (user_message)" "user_message"
[ -f "$SB/.specdev/specs/demo/recovery-instructions.md" ] \
    && ok "压缩恢复指南已落盘 recovery-instructions.md（该事件的真正交付物）" \
    || bad "recovery-instructions.md 未生成"
# AC-A5 一致性：两处锚定文本必须逐字来自同一实现（status-read.sh 的 emit_anchoring_block）。
# 若只改了 sessionStart 侧，压缩侧会留下旧文本 → 恢复后被引导做出与规则冲突的动作。
if [ -f "$SB/.specdev/specs/demo/recovery-instructions.md" ]; then
    for kw in "HG-1.5" "原型确认"; do
        if rg -q "$kw" "$SB/.specdev/specs/demo/recovery-instructions.md" 2>/dev/null; then
            ok "压缩恢复指南与 sessionStart 锚定一致：$kw"
        else
            bad "recovery-instructions.md 缺「$kw」—— 两处锚定已漂移"
        fi
    done
fi

echo "── preToolUse / pipeline-gate.sh（allow|deny，禁用 ask）──"
gate_out() {
    jq -nc --arg ws "$SB" '{tool_name:"Read",workspace_roots:[$ws],tool_input:{file_path:"/x"}}' \
        | bash .cursor/hooks/pipeline-gate.sh 2>/dev/null
}
OUT=$(gate_out)
assert_keys "$OUT" "输出只含文档定义字段" "permission user_message agent_message updated_input"
if printf '%s' "$OUT" | jq -r '.permission' 2>/dev/null | rg -qx 'ask'; then
    bad "preToolUse 上出现了 ask —— 文档明确该值「被接受但不执行」，等于放行"
else
    ok "preToolUse 未使用 ask（deny 才是被执行的拦截语义）"
fi
# 全局反查：gate 源码中不得再出现 permission:ask
if rg -q '"permission":"ask"|emit_ask' .cursor/hooks/pipeline-gate.sh 2>/dev/null; then
    bad "pipeline-gate.sh 源码中仍有 emit_ask / permission:ask"
else
    ok "pipeline-gate.sh 源码无 ask 用法"
fi

echo "── beforeShellExecution / shell-guard.sh（allow|deny|ask 三者均合法）──"
OUT=$(jq -nc '{command:"git status"}' | bash .cursor/hooks/shell-guard.sh 2>/dev/null)
assert_keys "$OUT" "allow 路径字段合法" "permission user_message agent_message"
OUT=$(jq -nc '{command:"cat /etc/shadow"}' | bash .cursor/hooks/shell-guard.sh 2>/dev/null)
assert_keys "$OUT" "ask 路径字段合法（该事件 ask 真实生效）" "permission user_message agent_message"
if printf '%s' "$OUT" | jq -r '.permission' 2>/dev/null | rg -qx 'ask'; then
    ok "敏感路径走 ask（交用户当场裁决）"
else
    bad "敏感路径未走 ask"
fi

echo "── hooks.json 注册的事件名必须都是官方文档中的真实事件 ──"
KNOWN_EVENTS="preToolUse postToolUse beforeShellExecution afterShellExecution beforeMCPExecution afterMCPExecution beforeReadFile afterFileEdit beforeSubmitPrompt afterAgentResponse afterAgentThought stop subagentStart subagentStop sessionStart sessionEnd preCompact workspaceOpen beforeTabFileRead afterTabFileEdit"
while IFS= read -r ev; do
    [ -z "$ev" ] && continue
    case " $KNOWN_EVENTS " in
        *" $ev "*) ok "事件名真实存在: $ev" ;;
        *) bad "hooks.json 注册了不存在的事件名: $ev" ;;
    esac
done < <(jq -r '.hooks | keys[]' .cursor/hooks.json 2>/dev/null)

echo "── hooks.json 注册的脚本必须都在磁盘上且可执行 ──"
# ⚠️ 为何必须断言可执行位（真实踩过）：
#   本测试内部一律用 `bash <script>` 调用被测 hook，因此**不依赖可执行位** → 测试全绿，
#   而 Cursor 是直接执行注册的路径，无 x 位时 hook 被静默跳过、无人察觉。
#   `drift-reminder.sh` 就曾因此从创建起一直没生效（与被它取代的 pipeline-advance.sh 同一个死法）。
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    if [ ! -f "$cmd" ]; then
        bad "脚本缺失: $cmd"
    elif [ ! -x "$cmd" ]; then
        bad "脚本无执行权限（Cursor 会静默跳过该 hook）: $cmd —— 修法：chmod +x $cmd"
    else
        ok "脚本存在且可执行: $cmd"
    fi
done < <(jq -r '.hooks[][].command' .cursor/hooks.json 2>/dev/null)

rm -rf "$SB"
printf '\n结果：%d 通过 / %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
