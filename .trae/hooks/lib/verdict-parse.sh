#!/bin/bash
# ============================================
# lib/verdict-parse.sh — verifier 判决解析共享库 (sourced，非独立执行)
# ============================================
# 供 Class C（pipeline-gate.sh）与 Class E（pipeline-advance.sh）通过 `source` 引入的
# 共享库，把 verifier 的 verification.md 判决/残余风险解析收敛于一处。
# 本库仅提供原语，不绑定任何 hook 事件、不产生独立执行的副作用。
#
# 3 个函数：
#   1) parse_verdict <verification.md 路径>
#        成功: echo PASS|PARTIAL|FAIL 到 stdout, return 0
#        无法解析（无判决行 / 判决行为多值枚举 / 值非法）: echo "" , return 1
#   1b) parse_review_verdict <review.md 路径>
#        成功: echo PASS|MUST-FIX|SHOULD-FIX 到 stdout, return 0
#        无法解析: echo "" , return 1
#        （供 pipeline-gate.sh 判定审查是否 MUST-FIX，取代原 `grep -oP` 实现）
#   2) max_residual_severity <verification.md 路径>
#        只扫「## 残余风险」区块（到下一个 ## 之前），扫 CRITICAL/MEDIUM/LOW 与 🔴/🟡/🟢
#        echo CRITICAL|MEDIUM|LOW|NONE 到 stdout, return 0（恒成功，NONE 兜底）
#   3) verdict_is_self_inconsistent <verification.md 路径>
#        判决=PASS 且 max_residual_severity ∈ {CRITICAL, MEDIUM} → return 0（矛盾）
#        否则 → return 1
#
# ⚠️ 可移植性铁律（重要）：
#   本库**严禁使用 `grep -P` / `grep -oP`**（PCRE 是 GNU 扩展）。macOS 的 BSD grep
#   遇到 -P 会以「invalid option -- P」退出码 2 失败；而 gate/advance 中大量 grep
#   用在 `if ! ...` 或 `$( ... || echo "")` 上下文中，失败会被静默吞掉并产生
#   **错误的方向**（例如白名单校验失败 → 误判为「不在白名单」→ 提前放行）。
#   所有正则一律用 POSIX：sed（捕获组替代 \K、[[:space:]] 替代 \s）、awk、grep -E/-F。
#
# 引入方（source 本文件）：
#   - pipeline-gate.sh      (PreToolUse, set -euo pipefail)   — Class C
#   - pipeline-advance.sh   (Stop, set -euo pipefail)         — Class E
#
# ⚠️ 调用约定（关键，照 status-read.sh）:
#   在 `set -euo pipefail` 的 hook 中，本库中「可失败」的函数（parse_verdict /
#   parse_review_verdict / verdict_is_self_inconsistent）**绝不能裸调用**，必须用
#   `if fn; then ...; fi` 或 `V=$(fn ... || echo "")` 包裹。在 `if`/`||`/`&&`/`$( || )`
#   上下文中调用时，bash 会在函数体内临时禁用 set -e，因此函数内部中间命令
#   （grep 无匹配等）失败不会误杀调用方。
#   max_residual_severity 恒返回 0（NONE 兜底），可直接 $(...) 捕获。
#
# 判决行契约（verifier.md）:
#   - 判决行格式：`## 判决：<VALUE>`，全角冒号「：」，<VALUE> ∈ {PASS, PARTIAL, FAIL}。
#   - 真实报告只保留单一值（如 `## 判决：PARTIAL`）；模板残留的多值枚举行
#     `## 判决：PASS / PARTIAL / FAIL` 必须视为「无 parseable verdict」。
#   - 只取第一处匹配（head -1）。
#   ⚠️ 绝不照抄 review.md 的粗体正则 `判决.*?\*\*`（那是 markdown 加粗格式），
#      本库用标题正则 `^##\s*判决[：:]\s*\K\S+`。
#
# 残余风险契约（verifier.md）:
#   - `## 残余风险` 标题后接 markdown 表 `| 风险 | 严重性 | 说明 |`。
#   - 严重性单元格含关键字 + emoji：`🔴 CRITICAL` / `🟡 MEDIUM` / `🟢 LOW`。
#   - 只扫「## 残余风险」到下一个 `##` 之间（避免误伤）。
#
# 库内部所有 grep/正则匹配写在 if 条件内或 $( ) 捕获中，绝不裸调用。
# ============================================

# ── parse_verdict <verification.md 路径> ──
# 提取判决值。用标题正则匹配 `## 判决：<VALUE>`（全角/半角冒号皆容），取第一处。
# 若匹配到多值枚举行（含 `/` 分隔多个判决词）或值非法，视为无可解析判决。
parse_verdict() {
    local file="${1:-}"

    # 文件缺失 → 无判决
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo ""
        return 1
    fi

    # 抽取判决行的冒号后剩余内容（第一处匹配）。全角「：」或半角「:」皆可。
    # ⚠️ 可移植性：不得使用 `grep -P`（PCRE 是 GNU 扩展，macOS 的 BSD grep 会以
    #   「invalid option -- P」退出码 2 失败），否则本函数在该平台恒返回「无判决」。
    #   改用 POSIX sed：`\K` 由捕获组替代，`\s` 由 [[:space:]] 替代。
    local raw
    raw=$(sed -n 's/^##[[:space:]]*判决[[:space:]]*[：:][[:space:]]*\(.*\)$/\1/p' "$file" 2>/dev/null | head -1 || echo "")

    # 去掉首尾空白
    raw=$(echo "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # 空 → 无判决行
    if [ -z "$raw" ]; then
        echo ""
        return 1
    fi

    # 多值枚举检测：判决行残留 `PASS / PARTIAL / FAIL` 这种多值枚举 → 视为无 parseable verdict。
    # 判据：冒号后同时出现 2 个及以上合法判决词（PASS/PARTIAL/FAIL）。
    local hit_count=0
    local w
    for w in PASS PARTIAL FAIL; do
        if echo "$raw" | grep -qwF "$w"; then
            hit_count=$((hit_count + 1))
        fi
    done
    if [ "$hit_count" -ge 2 ]; then
        # 多值枚举行（模板残留）→ 无可解析判决
        echo ""
        return 1
    fi

    # 单值：只取前导 token（形如 PASS / MUST-FIX），丢弃尾随说明
    #   例：`PARTIAL（原因：某些项未验证）` → `PARTIAL`
    #   ⚠️ 原实现用 `awk '{print $1}'`（等价于旧 `grep -oP '^\S+'`）依赖空格分隔，
    #      而 `PARTIAL（...）` 中间无空格 → 整串被当作 token → 判决解析失败。
    #      改用 sed 只截取开头的字母/连字符序列。
    local token
    token=$(echo "$raw" | sed -n 's/^\([A-Za-z][A-Za-z-]*\).*/\1/p' | head -1 || echo "")

    case "$token" in
        PASS|PARTIAL|FAIL)
            echo "$token"
            return 0
            ;;
        *)
            # 值非合法枚举 → 无可解析判决
            echo ""
            return 1
            ;;
    esac
}

# ── parse_review_verdict <review.md 路径> ──
# 提取合并后 review.md 的判决值（与 parse_verdict 同构，但枚举域不同）。
#   契约：真实 review.md 只能有一行 `## 判决：<VALUE>`，<VALUE> ∈ {PASS, MUST-FIX, SHOULD-FIX}
#   容错：值两侧的 markdown 粗体标记 `**` 会被剥除（`## 判决：**MUST-FIX**` 亦可解析）
#   成功: echo PASS|MUST-FIX|SHOULD-FIX, return 0
#   无法解析（无判决行 / 值非法）: echo "", return 1
#
# 用途：pipeline-gate.sh 在「标记 hg3=passed」与「派发 verifier」两处需要判定
#       审查是否为 MUST-FIX。此前用 `grep -oP '判决.*?\*\*\s*\K[^*]+'` 实现，
#       该写法在 BSD grep 上不可用（该平台恒返回空 → MUST-FIX 拦截永不生效）。
parse_review_verdict() {
    local file="${1:-}"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo ""
        return 1
    fi

    local raw
    raw=$(sed -n 's/^##[[:space:]]*判决[[:space:]]*[：:][[:space:]]*\(.*\)$/\1/p' "$file" 2>/dev/null | head -1 || echo "")

    # 去空白 + 剥离 markdown 粗体标记
    raw=$(echo "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/\*//g')

    if [ -z "$raw" ]; then
        echo ""
        return 1
    fi

    # 多值枚举（模板残留 `PASS / MUST-FIX / SHOULD-FIX`）→ 无可解析判决
    # 判据：出现 2 个及以上合法判决词，或含 `/` 分隔符
    local hit_count=0
    local w
    for w in PASS MUST-FIX SHOULD-FIX; do
        if echo "$raw" | grep -qwF "$w"; then
            hit_count=$((hit_count + 1))
        fi
    done
    if [ "$hit_count" -ge 2 ] || echo "$raw" | grep -q '/'; then
        echo ""
        return 1
    fi

    # 取前导 token（形如 PASS / MUST-FIX），丢弃尾随说明
    local token
    token=$(echo "$raw" | sed -n 's/^\([A-Za-z][A-Za-z-]*\).*/\1/p' | head -1 || echo "")

    case "$token" in
        PASS|MUST-FIX|SHOULD-FIX)
            echo "$token"
            return 0
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# ── max_residual_severity <verification.md 路径> ──
# 只扫「## 残余风险」区块（该标题下一行起，到下一个以 ## 开头的行之前），
# 扫描 CRITICAL/MEDIUM/LOW 关键字与 🔴/🟡/🟢 emoji，返回最高级。
# 无残余区块或区块内无任何风险标记 → NONE。
# 恒 return 0（NONE 兜底），可直接 SEV=$(max_residual_severity "$f")。
max_residual_severity() {
    local file="${1:-}"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "NONE"
        return 0
    fi

    # 抽取「## 残余风险」区块：从该标题的下一行开始，直到下一个 ## 标题（不含）。
    # awk 在 set -e 下正常退出（0），块内命令不会误杀调用方。
    local section
    section=$(awk '
        /^##[[:space:]]*残余风险/ { grab=1; next }
        grab && /^##/            { grab=0 }
        grab                     { print }
    ' "$file" 2>/dev/null || echo "")

    if [ -z "$section" ]; then
        echo "NONE"
        return 0
    fi

    # 从高到低判定：CRITICAL（关键字或 🔴）> MEDIUM（🟡）> LOW（🟢）。
    if echo "$section" | grep -qE 'CRITICAL|🔴'; then
        echo "CRITICAL"
        return 0
    fi
    if echo "$section" | grep -qE 'MEDIUM|🟡'; then
        echo "MEDIUM"
        return 0
    fi
    if echo "$section" | grep -qE 'LOW|🟢'; then
        echo "LOW"
        return 0
    fi

    echo "NONE"
    return 0
}

# ── verdict_is_self_inconsistent <verification.md 路径> ──
# 判决=PASS 且残余风险区含 CRITICAL/MEDIUM（含「已降级/downgraded」SOA 模式）→ return 0（矛盾）。
# 其余 → return 1。
# 注：max_residual_severity 已锚定在「## 残余风险」区块内，「已降级/downgraded」若出现在
# 该区块的 MEDIUM 行内即被 MEDIUM 命中，符合 SOA 模式（PASS 却私自把 MEDIUM 降级）。
verdict_is_self_inconsistent() {
    local file="${1:-}"

    local v
    v=$(parse_verdict "$file" || echo "")
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
