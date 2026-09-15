#!/bin/bash
# 自测：判决解析严格性 + 证据计数
cd "$(dirname "$0")/.." || exit 1
source .cursor/hooks/lib/verdict-parse.sh

TMP=$(mktemp -d)
pass=0; fail=0
chk() { # chk <期望> <实际> <用例名>
    if [ "$1" = "$2" ]; then printf '  ✅ %s → %s\n' "$3" "$2"; pass=$((pass+1))
    else printf '  ❌ %s → 期望[%s] 实际[%s]\n' "$3" "$1" "$2"; fail=$((fail+1)); fi
}

echo "── parse_review_verdict：5 种写法（旧实现有 3 条绕过路径）──"
run_review() { printf '%s\n' "$2" > "$TMP/r.md"; parse_review_verdict "$TMP/r.md" || printf ''; }

chk "MUST-FIX" "$(run_review x '## 判决：MUST-FIX')"                             "1 单值正常"
chk "MUST-FIX" "$(run_review x '## 判决：**MUST-FIX**')"                         "2 加粗（旧实现可解析）"
chk "MUST-FIX" "$(run_review x '## 判决：**MUST-FIX** / 需要修复')"               "3 加粗+追加说明 ← 旧实现放行"
chk "MUST-FIX" "$(run_review x '## 判决结果：MUST-FIX')"                          "4 标题为「判决结果」← 旧实现放行"
chk ""          "$(run_review x '## 判决：PASS / MUST-FIX / SHOULD-FIX')"         "5 多值枚举 ← 旧实现误判为 PASS"
chk "PASS"      "$(run_review x '## 判决：PASS')"                                 "6 单值 PASS"
chk ""          "$(run_review x '## 判决：完全没问题')"                            "7 非法值"

echo "── parse_verdict：verifier 判决 ──"
run_veri() { printf '%s\n' "$2" > "$TMP/v.md"; parse_verdict "$TMP/v.md" || printf ''; }
chk "PASS"    "$(run_veri x '## 判决：PASS')"                       "PASS"
chk "PARTIAL" "$(run_veri x '## 判决：PARTIAL（原因：某项未验证）')"  "PARTIAL + 括号说明"
chk "FAIL"    "$(run_veri x '## 判决：**FAIL**')"                    "加粗 FAIL"
chk ""        "$(run_veri x '## 判决：PASS / PARTIAL / FAIL')"       "多值枚举 → 拒绝"
chk ""        "$(run_veri x '## 无关标题：PASS')"                     "无判决行 → 拒绝"

echo "── count_blocking_findings：证据计数 ──"
run_cnt() { printf '%b\n' "$2" > "$TMP/c.md"; count_blocking_findings "$TMP/c.md"; }

chk "0" "$(run_cnt x '# R\n\n## Must-Fix 汇总\n（来自 4 份报告的所有 🔴 must-fix 条目合并）\n\n## Should-Fix 汇总\n- 🟡 小问题')" \
        "空模板占位（散文含 🔴 但不计）"
chk "3" "$(run_cnt x '# R\n\n## Must-Fix 汇总\n- 🔴 a\n- 🔴 b\n| 源 | 条目 |\n|---|---|\n| c | 🔴 c |\n\n## Should-Fix 汇总')" \
        "3 条（列表 2 + 表格 1）"
chk "1" "$(run_cnt x '# R\n### 🔴 Must-Fix\n- 🔴 未注册桩\n### 🟡 Should-Fix\n- 🟡 x')" \
        "并行报告 ### 🔴 Must-Fix 格式"
chk "0" "$(run_cnt x '# R\n### 🔴 Must-Fix\n- ...\n### 🟡 Should-Fix')" \
        "占位 - ... 不计"
chk "0" "$(run_cnt x '# R\n\n## 并行审查摘要\n| 视角 | 判决 |\n|---|---|\n| a | MUST-FIX |')" \
        "摘要表的 MUST-FIX 不计（非 Must-Fix 区）"

echo "── max_residual_severity / 自相矛盾 ──"
run_sev() { printf '%b\n' "$2" > "$TMP/s.md"; max_residual_severity "$TMP/s.md"; }
chk "CRITICAL" "$(run_sev x '## 判决：PARTIAL\n## 残余风险\n| 风险 | 严重性 |\n|---|---|\n| a | 🔴 CRITICAL |')" "CRITICAL"
chk "NONE"     "$(run_sev x '## 判决：PASS\n## 残余风险\n| 风险 | 严重性 |\n|---|---|\n| 无 | - |')" "无风险 → NONE"
run_inc() { printf '%b\n' "$2" > "$TMP/i.md"; if verdict_is_self_inconsistent "$TMP/i.md"; then printf 'INCONSISTENT'; else printf 'ok'; fi; }
chk "INCONSISTENT" "$(run_inc x '## 判决：PASS\n## 残余风险\n| a | 🟡 MEDIUM |')" "PASS+MEDIUM → 矛盾"
chk "ok"           "$(run_inc x '## 判决：PASS\n## 残余风险\n| a | 🟢 LOW |')"    "PASS+LOW → 不矛盾"

rm -rf "$TMP"
printf '\n结果：%d 通过 / %d 失败\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
