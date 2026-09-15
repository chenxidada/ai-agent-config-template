#!/bin/bash
# ============================================
# lib/verdict-parse.sh — 判决与证据解析共享库 (sourced，非独立执行)
# ============================================
# 供 pipeline-gate.sh（preToolUse）与 session-recovery.sh 等通过 `source` 引入的共享库，
# 把「审查/验证产出」的判决与阻塞项解析收敛于一处。
# 本库仅提供原语，不绑定任何 hook 事件、不产生独立执行的副作用。
#
# 4 个函数：
#   1) parse_verdict <verification.md 路径>
#        成功: echo PASS|PARTIAL|FAIL, return 0
#        无法解析（无判决行 / 多值枚举 / 值非法）: echo "", return 1
#   2) parse_review_verdict <review.md 路径>
#        成功: echo PASS|MUST-FIX|SHOULD-FIX, return 0
#        无法解析: echo "", return 1
#   3) count_blocking_findings <report.md 路径>
#        数「Must-Fix 区」内的阻塞条目（🔴 / MUST-FIX）
#        echo 数字, 恒 return 0（0 兜底）
#   4) max_residual_severity <verification.md 路径>
#        只扫「## 残余风险」区块，echo CRITICAL|MEDIUM|LOW|NONE, 恒 return 0
#   5) verdict_is_self_inconsistent <verification.md 路径>
#        判决=PASS 且残余含 CRITICAL/MEDIUM → return 0（矛盾）
#
# ⚠️ 可移植性铁律（重要）：
#   本库**严禁使用 `grep -P` / `grep -oP`**（PCRE 是 GNU 扩展）。macOS 的 BSD grep
#   遇到 -P 会以「invalid option -- P」退出码 2 失败；而 gate 中大量 grep 用在
#   `if ! ...` 或 `$( ... || echo "")` 上下文中，失败会被静默吞掉并产生
#   **错误的方向**（例如白名单校验失败 → 误判为「不在白名单」→ 提前放行）。
#   所有正则一律用 POSIX：sed（捕获组替代 \K、[[:space:]] 替代 \s）、awk、grep -E/-F。
#
# ⚠️ 调用约定（关键，照 status-read.sh 模式）:
#   本库中「可失败」的函数（parse_verdict / parse_review_verdict /
#   verdict_is_self_inconsistent）**绝不能裸调用**，必须用 `if fn; then ...; fi`
#   或 `V=$(fn ... || printf '')` 包裹。
#   count_blocking_findings / max_residual_severity 恒返回 0，可直接 $(...) 捕获。
#
# ── 判决解析契约（严格单值）──
#   判决行格式：`## 判决：<VALUE>`，全角冒号「：」或半角「:」皆可。
#   <VALUE> 必须**单值**且为合法枚举之一。
#
#   归一化：解析前剥除全部空白、markdown 强调符（** *）与反引号，
#   因此 `## 判决：**MUST-FIX**` 与 `## 判决：MUST-FIX / 需要修复` 均可正确解析。
#   标题容错：`## 判决结果：X` 亦可（匹配 `判决` 后到冒号前的任意字符）。
#
#   ⚠️ 与旧实现的差异（旧实现在三条路径上可被绕过 → 门禁静默放行）：
#     旧: `## 判决：**MUST-FIX** / 需要修复` → 判为「无可解析判决」→ 放行
#     新: 归一化后取前导 token → MUST-FIX（正确拦截）
#     旧: `## 判决结果：MUST-FIX` → 正则要求「判决」后紧跟冒号 → 判为无判决 → 放行
#     新: 标题容错 → MUST-FIX
#     旧: `## 判决：PASS / MUST-FIX / SHOULD-FIX`（模板残留）→ 误判为 PASS
#     新: 归一化后出现第二个判决词 → 拒绝（非法），由 gate 转为 deny
#
#   本库只负责「判决是否可解析」；「不可解析时该 allow 还是 deny」由调用方决定。
#
# ── 证据契约（count_blocking_findings）──
#   合并报告 review.md 的区块标题：`## Must-Fix 汇总`
#   并行 reviewer 报告 review-*.md 的区块标题：`### 🔴 Must-Fix`
#   只统计区块内的**列表项 / 表格行**，忽略散文占位（如「（来自 4 份报告的所有 🔴 ...合并）」），
#   避免空模板被误计为 1 条阻塞项。
#
#   设计意图（反「自陈」）：判决是 Agent 可自由书写的字段，而 🔴 条目是它自己产出的证据。
#   当二者矛盾时，以证据为准 —— gate 在 self-report=PASS 但 evidence>0 时仍 deny。
#
# ── 残余风险契约（max_residual_severity）──
#   `## 残余风险` 标题后接 markdown 表 `| 风险 | 严重性 | 说明 |`。
#   严重性单元格含关键字 + emoji：`🔴 CRITICAL` / `🟡 MEDIUM` / `🟢 LOW`。
#   只扫「## 残余风险」到下一个 `##` 之间。
#
# 库内部所有 grep/正则匹配写在 if 条件内或 $( ) 捕获中，绝不裸调用。
# ============================================

# ── _parse_verdict_line <文件> <合法枚举 ERE> ──
# 唯一的判决解析实现；parse_verdict / parse_review_verdict 是它的两个实例。
_parse_verdict_line() {
    local file="${1:-}" allow="${2:-}"

    if [ -z "$file" ] || [ ! -f "$file" ] || [ -z "$allow" ]; then
        printf '%s' ""
        return 1
    fi

    # 抽取判决行冒号后的剩余内容（第一处匹配）。
    # 标题容错：`判决` 与冒号之间允许任意字符（覆盖「判决结果：」）。
    # ⚠️ 可移植性：不得使用 grep -P；`\K` 由捕获组替代，`\s` 由 [[:space:]] 替代。
    local raw
    raw=$(sed -n 's/^##[[:space:]]*判决[^：:]*[：:][[:space:]]*\(.*\)$/\1/p' "$file" 2>/dev/null | head -1)

    # 归一化：去掉全部空白 + markdown 强调符 + 反引号。
    # 去空白（而非仅首尾）是关键：让 `MUST-FIX / 需要修复` 与 `MUST-FIX/需要修复` 等价。
    local norm
    norm=$(printf '%s' "$raw" | sed 's/[[:space:]]//g; s/\*//g; s/`//g')

    if [ -z "$norm" ]; then
        printf '%s' ""
        return 1
    fi

    # 取前导 token（字母/连字符序列），丢弃尾随说明。
    # 例：`PARTIAL（原因：某项未验证）` → `PARTIAL`
    local token
    token=$(printf '%s' "$norm" | sed -n 's/^\([A-Za-z][A-Za-z-]*\).*/\1/p' | head -1)

    # token 必须恰好是合法枚举之一（-x 全行匹配）
    if ! printf '%s' "$token" | grep -qxE "$allow" 2>/dev/null; then
        printf '%s' ""
        return 1
    fi

    # 去掉前导 token 后，若仍残留另一个判决词 → 多值枚举 / 自相矛盾 → 拒绝。
    # 这一步同时覆盖「模板残留 `PASS / MUST-FIX / SHOULD-FIX`」与
    # 「正常值后追加另一个判决词」两类写法。
    local rest
    rest=$(printf '%s' "$norm" | sed "s/^${token}//" \
        | grep -owE 'PASS|PARTIAL|FAIL|MUST-FIX|SHOULD-FIX' 2>/dev/null | head -1)
    if [ -n "$rest" ]; then
        printf '%s' ""
        return 1
    fi

    printf '%s' "$token"
    return 0
}

# ── parse_verdict <verification.md 路径> ──
# 成功: echo PASS|PARTIAL|FAIL, return 0
# 无法解析: echo "", return 1
parse_verdict() {
    _parse_verdict_line "${1:-}" 'PASS|PARTIAL|FAIL'
}

# ── parse_review_verdict <review.md 路径> ──
# 成功: echo PASS|MUST-FIX|SHOULD-FIX, return 0
# 无法解析: echo "", return 1
# 用途：gate 在「标记 hg3=passed」与「派发 verifier」两处判定审查是否 MUST-FIX。
parse_review_verdict() {
    _parse_verdict_line "${1:-}" 'PASS|MUST-FIX|SHOULD-FIX'
}

# ── count_blocking_findings <报告路径> ──
# 数「Must-Fix 区」内的列表项 / 表格行中含 🔴 或 MUST-FIX 的条目数。
# 兼容两种区块标题：`## Must-Fix 汇总`（合并报告）/ `### 🔴 Must-Fix`（并行报告）。
# 恒 return 0，输出纯数字（0 兜底），可直接 N=$(count_blocking_findings "$f")。
count_blocking_findings() {
    local file="${1:-}" n

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        printf '0'
        return 0
    fi

    # awk：定位区块 → 只保留 列表项 / 表格行 → 交 grep 计数。
    # 只取列表/表格行是本函数的关键：它排除了散文占位行
    # （如 `（来自 4 份报告的所有 🔴 must-fix 条目合并）`），
    # 否则未填写的空模板会被误计为 1 条阻塞项。
    n=$(awk '
        /^##+[[:space:]]*(🔴[[:space:]]*)?Must-Fix/ { grab=1; next }
        grab && /^##+[[:space:]]/                    { grab=0 }
        grab && /^[[:space:]]*([-*+]|[0-9]+\.)[[:space:]]/ { print; next }
        grab && /^[[:space:]]*\|/                    { print }
    ' "$file" 2>/dev/null | grep -cE '🔴|MUST-FIX' 2>/dev/null)

    case "$n" in
        ''|*[!0-9]*) n=0 ;;
    esac

    printf '%s' "$n"
    return 0
}

# ── max_residual_severity <verification.md 路径> ──
# 只扫「## 残余风险」区块（该标题下一行起，到下一个以 ## 开头的行之前），
# 扫描 CRITICAL/MEDIUM/LOW 关键字与 🔴/🟡/🟢 emoji，返回最高级。
# 无残余区块或区块内无任何风险标记 → NONE。
# 恒 return 0（NONE 兜底），可直接 SEV=$(max_residual_severity "$f")。
max_residual_severity() {
    local file="${1:-}"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        printf 'NONE'
        return 0
    fi

    local section
    section=$(awk '
        /^##[[:space:]]*残余风险/ { grab=1; next }
        grab && /^##/            { grab=0 }
        grab                     { print }
    ' "$file" 2>/dev/null)

    if [ -z "$section" ]; then
        printf 'NONE'
        return 0
    fi

    if printf '%s' "$section" | grep -qE 'CRITICAL|🔴' 2>/dev/null; then
        printf 'CRITICAL'
        return 0
    fi
    if printf '%s' "$section" | grep -qE 'MEDIUM|🟡' 2>/dev/null; then
        printf 'MEDIUM'
        return 0
    fi
    if printf '%s' "$section" | grep -qE 'LOW|🟢' 2>/dev/null; then
        printf 'LOW'
        return 0
    fi

    printf 'NONE'
    return 0
}

# ── verdict_is_self_inconsistent <verification.md 路径> ──
# 判决=PASS 且残余风险区含 CRITICAL/MEDIUM（含「已降级/downgraded」SOA 模式）→ return 0（矛盾）。
# 其余 → return 1。
verdict_is_self_inconsistent() {
    local file="${1:-}"

    local v
    v=$(parse_verdict "$file" || printf '%s' "")
    if [ "$v" != "PASS" ]; then
        return 1
    fi

    local sev
    sev=$(max_residual_severity "$file")
    if [ "$sev" = "CRITICAL" ] || [ "$sev" = "MEDIUM" ]; then
        return 0
    fi
    return 1
}
