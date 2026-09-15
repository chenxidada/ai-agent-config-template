#!/bin/bash
# ============================================================
# test-gate.sh — pipeline-gate.sh 行为测试（构造 payload 断言 allow/deny）
# ============================================================
# 为什么需要：门禁自身此前从无验证者。本脚本用真实 hook 输入格式喂给
# pipeline-gate.sh，断言其判定，覆盖 v8 修复的全部 fail-open 点。
#
# 用法：bash tools/test-gate.sh
# 退出码：0 = 全部通过；1 = 有失败
# ============================================================
cd "$(dirname "$0")/.." || exit 1
GATE=".cursor/hooks/pipeline-gate.sh"

pass=0; fail=0

# gate <payload JSON> → 输出 permission 值（allow/deny）
gate() { printf '%s' "$1" | bash "$GATE" 2>/dev/null | jq -r '.permission // "?"' 2>/dev/null; }

# 断言
chk() { # chk <期望> <payload> <用例名>
    local got
    got=$(gate "$2")
    if [ "$1" = "$got" ]; then printf '  ✅ %s → %s\n' "$3" "$got"; pass=$((pass+1))
    else printf '  ❌ %s → 期望[%s] 实际[%s]\n' "$3" "$1" "$got"; fail=$((fail+1)); fi
}

# ── 沙箱：一个可完全控制的「目标项目」──
SB=$(mktemp -d)
mkdir -p "$SB/.specdev/specs/demo/phases/phase-1"
printf 'demo\n' > "$SB/.specdev/active-workflow"
PHASE_DIR="$SB/.specdev/specs/demo/phases/phase-1"
SPEC_DIR="$SB/.specdev/specs/demo"

# 供 design.md「现状依据」引用的真实文件（v8.4 起门禁核验证据路径是否存在、行号是否越界）。
# 必须真实存在于沙箱内 —— 否则「证据指向真实位置」这条校验无法被测试证明。
# ⚠️ 证据只能用**沙箱内**的路径：PROJECT_ROOT 由 payload 的 workspace_roots[0] 决定，
#    指向沙箱而非真实仓库，引用仓库内路径会被 L4 正确拒绝。
mkdir -p "$SB/src"
printf 'export const a = 1;\nexport const b = 2;\nexport const c = 3;\nexport const d = 4;\nexport const e = 5;\n' > "$SB/src/demo.ts"
printf 'export const timeout = 3000;\nexport const retries = 2;\n' > "$SB/src/config.ts"

# 基线 spec 文件：hg1/hg2 检查要求它们存在且有效。
# 注意：写入的 status JSON 通常包含全部 human_gates 字段，因此
# 「已 passed 的 hg1/hg2」每次写入都会被重新校验 —— 这是既有的设计（v7 同）。
base_specs() {
    printf '# 需求\n\n## 验收标准\n%s\n' "$(seq 1 12 | sed 's/^/- AC/')" > "$SPEC_DIR/requirements.md"
    # design.md 必须含「现状依据」章节（v8.4 起 hg2=passed 会校验 L1–L5）。
    # 证据刻意指向沙箱内**真实存在**的文件与**合法**行号 —— 夹具要还原"合格的设计"，
    # 而不是给门禁留一个绕过口（那会让新校验在测试里永远为绿）。
    {
        printf '# 设计\n\n'
        printf '## 现状依据\n\n'
        printf '| 事实 | 证据 |\n|------|------|\n'
        printf '| 沙箱基线文件导出 5 个常量 | `src/demo.ts:1` |\n'
        printf '| 沙箱配置定义超时与重试 | `src/config.ts:2` |\n'
        printf '\n## 架构决策\n'
        seq 1 12 | sed 's/^/- 决策/'
    } > "$SPEC_DIR/design.md"
    # phase-plan.md 需 ≥10 行（gate 的 hg2 内容完整性检查，v7 既有行为），
    # 故这里写成含散文 + DAG JSON 代码块的真实形态。
    cat > "$SPEC_DIR/phase-plan.md" <<'PP'
# Phase 计划

## Phase 拆分

| Phase | 范围 | 依赖 | 产出 |
|-------|------|------|------|
| phase-1 | 门禁加固 | - | hook v8 |

## DAG

```json
{"phases":[{"id":"phase-1","ui":false,"dependencies":[]}]}
```
PP
}
base_specs

# 技术债注册表：真实流程中由 /feature 初始化时从模板复制。
# gate 在 hg3=passed 时会校验它存在 —— 夹具必须还原这个事实，
# 否则「产物齐全 → allow」这条用例会被新校验误判为 deny（夹具失真，而非门禁过严）。
DEBT_FILE="$SPEC_DIR/tech-debt-registry.md"
printf '# Tech Debt Registry\n\n## 活跃债务\n\n| ID | 源Phase | 位置 |\n|----|--------|------|\n| — | — | — |\n\n## 已解决\n\n| ID | 描述 |\n|----|------|\n| — | — |\n' > "$DEBT_FILE"

write_status() { # write_status <hg3> <loop_count> <verifier_loop_count>
    cat > "$SB/.specdev/specs/demo/current-status.json" <<EOF
{
  "slug": "demo",
  "description": "门禁测试",
  "created": "2026-09-15T00:00:00Z",
  "current_stage": "phase-implementation",
  "current_phase": "phase-1",
  "loop_count": $2,
  "verifier_loop_count": $3,
  "human_gates": { "hg1": "passed", "hg2": "passed", "hg3": "$1" },
  "phases": { "phase-1": { "implementer": "completed", "reviewer": "completed", "verifier": "completed" } },
  "last_update": "2026-09-15T00:00:00Z"
}
EOF
}

# 写入任意 current-status.json 内容（用于构造 payload 的 content 字段）
status_json() { # status_json <hg3> <loop> <phase> [extra]
    printf '{"slug":"demo","current_stage":"phase-implementation","current_phase":"%s","loop_count":%s,"human_gates":{"hg1":"passed","hg2":"passed","hg3":"%s"}%s}' "$3" "$2" "$1" "${4:-}"
}

# payload 构造器
p_write_status() { # p_write_status <content>
    jq -nc --arg c "$1" --arg ws "$SB" \
        '{tool_name:"Write",workspace_roots:[$ws],tool_input:{file_path:($ws+"/.specdev/specs/demo/current-status.json"),content:$c}}'
}
p_write_other() { # p_write_other <path>
    jq -nc --arg p "$1" --arg ws "$SB" \
        '{tool_name:"Write",workspace_roots:[$ws],tool_input:{file_path:$p,content:"x"}}'
}
p_task() { # p_task <subagent_type>
    jq -nc --arg s "$1" --arg ws "$SB" \
        '{tool_name:"Task",workspace_roots:[$ws],tool_input:{subagent_type:$s,prompt:"x"}}'
}

# 填充一个「干净通过」的 Phase 产物
clean_phase() {
    printf '# Impl\n\n## 变更清单\n%s\n' "$(seq 1 15 | sed 's/^/- 行/')" > "$PHASE_DIR/implementation.md"
    printf '# 审查报告（合并）\n\n## 判决：PASS\n\n## Must-Fix 汇总\n（来自 4 份报告的所有 🔴 must-fix 条目合并）\n\n## Should-Fix 汇总\n- 🟡 命名建议\n' > "$PHASE_DIR/review.md"
    printf '# 验证报告\n\n## 判决：PASS\n\n## 残余风险\n| 风险 | 严重性 |\n|---|---|\n| 无 | - |\n' > "$PHASE_DIR/verification.md"
}

# ════════════════════════════════════════════════════════════
echo "── 1. 无活跃工作流：日常写入不得被误伤 ──"
mv "$SB/.specdev/active-workflow" "$SB/.specdev/aw.bak"
chk "allow" "$(p_write_other "$SB/src/app.py")" "无工作流 + 写实现代码 → allow（不误伤日常开发）"
chk "deny"  "$(p_write_status "$(status_json pending 0 phase-1)")" "无工作流 + 写状态文件 → deny（孤儿状态）"
mv "$SB/.specdev/aw.bak" "$SB/.specdev/active-workflow"

echo "── 1b. bootstrap 路径（v8 首版曾在此引入回归，测试套件当时未覆盖）──"
# /feature 顺序：建目录 → 写 active-workflow → 初始化 current-status.json
#   此时状态文件【尚不存在】，且初始化内容含 current_phase:"" + 全 pending
rm -f "$SB/.specdev/specs/demo/current-status.json"
INIT_JSON='{"slug":"demo","description":"新工作流","created":"2026-09-15T00:00:00Z","current_stage":"requirement-analysis","current_phase":"","loop_count":0,"human_gates":{"hg1":"pending","hg2":"pending","hg3":"pending"},"phases":{},"last_update":"2026-09-15T00:00:00Z"}'
chk "allow" "$(p_write_status "$INIT_JSON")" "/feature 首次初始化 → allow ← v8 首版误判为 deny（工作流无法启动）"
chk "deny"  "$(p_write_status "$(printf '%s' "$INIT_JSON" | jq -c '.human_gates.hg1="passed"')")" \
    "初始化即声称 hg1=passed → deny"
chk "deny"  "$(p_write_status "$(printf '%s' "$INIT_JSON" | jq -c '.current_phase="phase-1"')")" \
    "初始化即设置 current_phase → deny"

echo "── 1c. 规划阶段的 current_phase:\"\" 是正常状态，不得被「清空检测」误伤 ──"
write_status pending 0 0
cat > "$SB/.specdev/specs/demo/current-status.json" <<'EOF'
{"slug":"demo","current_stage":"requirement-analysis","current_phase":"","loop_count":0,
 "human_gates":{"hg1":"pending","hg2":"pending","hg3":"pending"},"phases":{}}
EOF
chk "allow" "$(p_write_status "$(printf '%s' "$INIT_JSON" | jq -c '.human_gates.hg1="passed"')")" \
    "需求阶段写 hg1=passed（current_phase 仍为空）→ allow"

echo "── 1d. 非空但非法 JSON 的写入（残留 fail-open：全部 grep 静默不匹配）──"
write_status pending 0 0
chk "deny" "$(p_write_status '{"slug":"demo","human_gates":{"hg3":"pas')" "内容非空但非法 JSON → deny"
chk "deny" "$(p_write_status 'diff --git a/x b/x')"                  "内容是 diff 片段而非完整文件 → deny"

echo "── 1e. 技术债登记校验（hg3=passed 时）──"
write_status pending 0 0
clean_phase
mv "$DEBT_FILE" "$DEBT_FILE.bak"
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" \
    "注册表缺失 → deny（工作流初始化被跳过）"
mv "$DEBT_FILE.bak" "$DEBT_FILE"
chk "allow" "$(p_write_status "$(status_json passed 0 phase-1)")" \
    "注册表在 + 无桩声明 → allow"

# 声明了桩但未登记 → deny（这是「@STUB 必须先入册」的程序化落点）
printf '# Impl\n\n## 变更清单\n%s\n\n## 桩\n- `@STUB(phase-1-payment-gateway)` 仅返回固定值\n' \
    "$(seq 1 15 | sed 's/^/- 行/')" > "$PHASE_DIR/implementation.md"
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" \
    "声明 @STUB 但注册表无对应条目 → deny"
# 登记后 → allow
printf '\n| STUB-1 | phase-1 | `@STUB(phase-1-payment-gateway)` | 返回固定值 | 真实调用 | 空实现 | 🔴 |\n' >> "$DEBT_FILE"
chk "allow" "$(p_write_status "$(status_json passed 0 phase-1)")" \
    "@STUB 已登记 → allow"
# 只登记 @STUB 的**无括号**散文提及不应被当成漏登记（正则要求带括号）
printf '# Impl\n\n## 变更清单\n%s\n\n## 说明\n本 Phase 无 @STUB 遗留。\n' \
    "$(seq 1 15 | sed 's/^/- 行/')" > "$PHASE_DIR/implementation.md"
chk "allow" "$(p_write_status "$(status_json passed 0 phase-1)")" \
    "「无 @STUB 遗留」这类散文提及不误报 → allow"
clean_phase

echo "── 2. 非状态文件的写入 ──"
chk "allow" "$(p_write_other "$SB/src/app.py")" "有工作流 + 写实现代码 → allow（该约束未启用，见决策）"

echo "── 3. hg3=passed 的完整流程校验 ──"
clean_phase
write_status pending 0 0
chk "allow" "$(p_write_status "$(status_json passed 0 phase-1)")" "产物齐全 + 判决 PASS → allow"

write_status pending 0 0
chk "deny" "$(p_write_status "$(jq -nc '{slug:"demo",current_stage:"phase-implementation",current_phase:"",loop_count:0,human_gates:{hg1:"passed",hg2:"passed",hg3:"passed"}}')")" \
    "current_phase 为空却写 hg3=passed → deny ← 旧实现放行（最严重 fail-open）"

write_status pending 0 0
rm -f "$PHASE_DIR/verification.md"
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "verification.md 缺失 → deny"
clean_phase

echo "── 4. 判决解析：三条旧绕过路径 ──"
mkdir -p "$PHASE_DIR"
printf '# 审查报告（合并）\n\n## 判决：**MUST-FIX** / 需要修复\n' > "$PHASE_DIR/review.md"
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "判决「加粗+追加说明」→ deny ← 旧实现放行"

printf '# 审查报告（合并）\n\n## 判决结果：MUST-FIX\n' > "$PHASE_DIR/review.md"
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "标题为「判决结果」→ deny ← 旧实现放行"

printf '# 审查报告（合并）\n\n## 判决：PASS / MUST-FIX / SHOULD-FIX\n' > "$PHASE_DIR/review.md"
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "多值枚举 → deny ← 旧实现误判为 PASS"

echo "── 5. 证据优先：自陈 PASS 但 Must-Fix 区有 🔴 ──"
printf '# 审查报告（合并）\n\n## 判决：PASS\n\n## Must-Fix 汇总\n- 🔴 未注册桩 auth.ts:42\n- 🔴 边界未处理\n\n## Should-Fix 汇总\n' > "$PHASE_DIR/review.md"
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "自陈 PASS + 2 条 🔴 → deny（证据优先）"

# 合并报告干净，但并行原始报告有 🔴 → 仍 deny
clean_phase
printf '# Correctness Review\n\n### 🔴 Must-Fix\n- 🔴 未注册桩\n' > "$PHASE_DIR/review-correctness.md"
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "合并干净但并行报告有 🔴 → deny（防合并丢失）"
rm -f "$PHASE_DIR/review-correctness.md"

echo "── 6. verifier 判决（原 ask 空操作，现 deny）──"
printf '# 验证报告\n\n## 判决：PARTIAL\n' > "$PHASE_DIR/verification.md"
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "verifier 判决 PARTIAL → deny ← 旧实现 ask（等同放行）"

printf '# 验证报告\n\n## 判决：PASS\n\n## 残余风险\n| 风险 | 严重性 |\n|---|---|\n| a | 🟡 MEDIUM |\n' > "$PHASE_DIR/verification.md"
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1)")" "判决 PASS 但残余含 MEDIUM → deny（自相矛盾）"

clean_phase
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json passed 0 phase-1 ',"verifier_loop_count":2')")" "verifier_loop_count=2 且推进 → deny（熔断）"

echo "── 7. 数字字段污染（旧实现抛错后静默放行）──"
clean_phase
write_status pending 0 0
chk "allow" "$(p_write_status "$(status_json passed 0 phase-1 ',"verifier_loop_count":"abc"')")" 'verifier_loop_count:"abc" → 不崩溃，按 0 处理'

echo "── 8. 阶段跳跃 / 状态破坏 ──"
clean_phase
write_status pending 0 0
chk "deny" "$(p_write_status "$(status_json pending 0 phase-2)")" "hg3=pending 却切 current_phase → deny"

clean_phase
write_status pending 0 0
chk "deny" "$(p_write_status "$(jq -nc '{slug:"demo",current_stage:"phase-implementation",current_phase:"",loop_count:0,human_gates:{hg1:"passed",hg2:"passed",hg3:"passed"}}')")" \
    "显式清空 current_phase → deny（不得回落旧值绕过）"

echo "── 9. 子 Agent 白名单（旧实现未知名字放行）──"
clean_phase; write_status pending 0 0
chk "deny"  "$(p_task implementr)"        "拼错的名字 implementr → deny ← 旧实现放行全部门禁"
chk "deny"  "$(p_task some-other-agent)"  "未登记 Agent → deny"
chk "deny"  "$(p_task implementer)"       "implementer 但分支/前置不符 → deny"
chk "allow" "$(p_task plan-generator)"    "plan-generator（hg1=passed + requirements 有效）→ allow"
chk "allow" "$(p_task explore)"           "内置 explore → allow"

echo "── 10. Phase ID 必须来自 DAG JSON ──"
printf '# spec\n%s\n' "$(seq 1 12)"    > "$PHASE_DIR/spec.md"
printf '# repo\n%s\n' "$(seq 1 12)"    > "$PHASE_DIR/repo-exploration.md"
write_status pending 0 0
chk "allow" "$(p_task code-explorer)" "合法 DAG + 合法 phase ID → allow"

printf '```json\n{"phases":[{"id":"other-phase","ui":false}]}\n```\n' > "$SPEC_DIR/phase-plan.md"
write_status pending 0 0
chk "deny" "$(p_task code-explorer)" "current_phase 不在 DAG JSON 中 → deny（Phase ID 铁律）"

rm -f "$SPEC_DIR/phase-plan.md"
write_status pending 0 0
chk "deny" "$(p_task code-explorer)" "DAG 文件缺失 → deny ← 旧实现 return 0 放行"

echo "── 11. implementer 分支隔离 ──"
printf '```json\n{"phases":[{"id":"phase-1","ui":false}]}\n```\n' > "$SPEC_DIR/phase-plan.md"
git -C "$SB" init -q 2>/dev/null
git -C "$SB" add -A 2>/dev/null
git -C "$SB" -c user.email=t@t -c user.name=t commit -qm init 2>/dev/null
write_status pending 0 0
chk "deny"  "$(p_task implementer)" "在 main 分支派 implementer → deny（分支不匹配）"
git -C "$SB" checkout -qb impl-phase-1 2>/dev/null
chk "allow" "$(p_task implementer)" "在 impl-phase-1 分支 → allow（完整前置齐备）"

echo "── 12. UI Phase 判定三态（旧实现解析失败即静默关闭 UI 门禁）──"
printf '```json\n{"phases":[{"id":"phase-1","ui":true}]}\n```\n' > "$SPEC_DIR/phase-plan.md"
write_status pending 0 0
chk "deny" "$(p_task implementer)" "ui:true 但缺 ui-spec/visual-baseline → deny"
printf '```json\n{"phases":[{"id":"phase-1"}]}\n```\n' > "$SPEC_DIR/phase-plan.md"
write_status pending 0 0
chk "deny" "$(p_task implementer)" "DAG 缺 ui 字段 → deny ← 旧实现当作 false 静默放行"

echo "── 13. 未知工具 / 只读工具不干扰 ──"
chk "allow" "$(jq -nc --arg ws "$SB" '{tool_name:"Read",workspace_roots:[$ws],tool_input:{file_path:"/x"}}')" "Read → allow"

echo "── 14. code-explorer 双模式分流（旧实现对「设计前调研」一律 deny）──"
# 旧实现无条件套 validate_phase_id：current_phase 为空即 gate_unknown → deny。
# 后果是 /plan、/bugfix 的设计前调研、以及任一工作流内的 /research 全部不可达。
# 唯一可达路径是「状态文件根本不存在」（bootstrap 分支的副作用，非设计）。
# 设计/需求阶段状态：current_phase 为空
write_design_status() { # write_design_status <current_stage> [hg1]
    cat > "$SB/.specdev/specs/demo/current-status.json" <<EOF
{
  "slug": "demo",
  "description": "门禁测试",
  "created": "2026-09-15T00:00:00Z",
  "current_stage": "$1",
  "current_phase": "",
  "loop_count": 0,
  "human_gates": { "hg1": "${2:-passed}", "hg2": "pending", "hg3": "pending" },
  "phases": {},
  "last_update": "2026-09-15T00:00:00Z"
}
EOF
}
write_design_status architecture-design
chk "allow" "$(p_task code-explorer)" "空 current_phase + architecture-design → allow ← 旧实现 deny（设计前调研被门禁关闭）"
write_design_status requirement-analysis pending
chk "allow" "$(p_task code-explorer)" "空 current_phase + requirement-analysis → allow ← 旧实现 deny"
write_design_status phase-implementation
chk "deny" "$(p_task code-explorer)" "空 current_phase + phase-implementation → deny（状态损坏，fail-closed）"

echo "── 15. design.md「现状依据」L1–L5（hg2=passed 时校验）──"
# 夹具恢复干净基线（base_specs 会重写 design.md / phase-plan.md）
base_specs
H2='{"slug":"demo","current_stage":"architecture-design","loop_count":0,"human_gates":{"hg1":"passed","hg2":"passed","hg3":"pending"}}'
p_hg2_payload() { # p_hg2_payload <content>
    jq -nc --arg c "$1" --arg ws "$SB" \
        '{tool_name:"Write",workspace_roots:[$ws],tool_input:{file_path:($ws+"/.specdev/specs/demo/current-status.json"),content:$c}}'
}

write_design() { # write_design <现状依据章节正文>
    {
        printf '# 设计\n\n## 现状依据\n\n%s\n\n## 架构决策\n' "$1"
        seq 1 12 | sed 's/^/- 决策/'
    } > "$SPEC_DIR/design.md"
}

# L1：无章节
{
    printf '# 设计\n\n## 架构决策\n'
    seq 1 12 | sed 's/^/- 决策/'
} > "$SPEC_DIR/design.md"
write_design_status architecture-design
chk "deny" "$(p_hg2_payload "$H2")" "L1 design.md 无「现状依据」章节 → deny"

# L3：只有散文，无 `path:line`
write_design '现有架构大致采用分层设计，鉴权位于中间件层。'
write_design_status architecture-design
chk "deny" "$(p_hg2_payload "$H2")" "L3 仅有散文描述、无 \`路径:行号\` → deny"

# L4：路径不存在
write_design '| 事实 | 证据 |
|------|------|
| 某不存在的文件 | `src/nonexistent.ts:1` |'
write_design_status architecture-design
chk "deny" "$(p_hg2_payload "$H2")" "L4 证据指向不存在的路径 → deny（编造路径被抓）"

# L5：行号越界
write_design '| 事实 | 证据 |
|------|------|
| 配置定义 | `src/config.ts:99` |'
write_design_status architecture-design
chk "deny" "$(p_hg2_payload "$H2")" "L5 行号超出文件实际行数 → deny（编造行号被抓）"

# 逃生舱：显式声明不依赖现有代码
write_design '本设计不依赖现有代码：本 Phase 仅新增独立脚本，不引用任何既有模块。'
write_design_status architecture-design
chk "allow" "$(p_hg2_payload "$H2")" "显式声明「本设计不依赖现有代码」→ allow（无依据必须留痕，不能是沉默默认）"

# 绿：证据真实且行号合法
write_design '| 事实 | 证据 |
|------|------|
| 沙箱基线导出常量 | `src/demo.ts:1` |
| 沙箱配置含超时 | `src/config.ts:2` |'
write_design_status architecture-design
chk "allow" "$(p_hg2_payload "$H2")" "L1–L5 全通过（证据指向真实位置且行号合法）→ allow"

rm -rf "$SB"
printf '\n结果：%d 通过 / %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
