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
#   2) max_residual_severity <verification.md 路径>
#        只扫「## 残余风险」区块（到下一个 ## 之前），扫 CRITICAL/MEDIUM/LOW 与 🔴/🟡/🟢
#        echo CRITICAL|MEDIUM|LOW|NONE 到 stdout, return 0（恒成功，NONE 兜底）
#   3) verdict_is_self_inconsistent <verification.md 路径>
#        判决=PASS 且 max_residual_severity ∈ {CRITICAL, MEDIUM} → return 0（矛盾）
#        否则 → return 1
#
# 引入方（source 本文件）：
#   - pipeline-gate.sh      (preToolUse, Cursor hook)   — Class C
#   - pipeline-advance.sh   (subagentStop, Cursor hook) — Class E
#
# ⚠️ 调用约定（关键，照 status-read.sh 模式）:
#   本库中「可失败」的函数（parse_verdict / verdict_is_self_inconsistent）
#   **绝不能裸调用**，必须用 `if fn; then ...; fi` 或 `V=$(fn ... || echo "")` 包裹。
#   max_residual_severity 恒返回 0（NONE 兜底），可直接 $(...) 捕获。
#
# 判决行契约（verifier.md）:
#   - 判决行格式：`## 判决：<VALUE>`，全角冒号「：」，<VALUE> ∈ {PASS, PARTIAL, FAIL}。
#   - 真实报告只保留单一值（如 `## 判决：PARTIAL`）；模板残留的多值枚举行
#     `## 判决：PASS / PARTIAL / FAIL` 必须视为「无 parseable verdict」（触发 AC-15）。
#   - 只取第一处匹配（head -1）。
#   ⚠️ 绝不照抄 review.md 的粗体正则 `判决.*?\*\*`（那是 markdown 加粗格式），
#      本库用标题正则 `^##\s*判决[：:]\s*\K\S+`。
#
# 残余风险契约（verifier.md）:
#   - `## 残余风险` 标题后接 markdown 表 `| 风险 | 严重性 | 说明 |`。
#   - 严重性单元格含关键字 + emoji：`🔴 CRITICAL` / `🟡 MEDIUM` / `🟢 LOW`。
#   - 只扫「## 残余风险」到下一个 `##` 之间（AC-16 误伤缓解）。
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
    # grep -oP 无匹配返回 1；包在 $( ) + || echo "" 中，set -e 不误杀。
    local raw
    raw=$(grep -oP '^##\s*判决\s*[：:]\s*\K.+$' "$file" 2>/dev/null | head -1 || echo "")

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

    # 单值：取第一个 token（防止 `PARTIAL（原因...）` 尾随说明）
    local token
    token=$(echo "$raw" | grep -oP '^\S+' | head -1 || echo "")

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
