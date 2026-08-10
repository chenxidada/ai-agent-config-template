#!/bin/bash
# ============================================
# lib/drift-lib.sh — 漂移守卫共享库 (sourced，非独立执行)
# ============================================
# 供块 A（命令熔断）与块 B（产出契约校验）的 hook 通过 `source` 引入的共享库。
# 本库仅提供原语，不绑定任何 hook 事件、不产生独立执行的副作用。
#
# 5 类原语：
#   1) 失败指纹    — compute_fingerprint            (AC-A2 / AC-A7 部分)
#   2) 计数读写    — read_counter / bump_or_reset / reset_counter (AC-A3 / A6 / A10)
#   3) 命令归类    — is_build_test_cmd + CMD_BUILD_TEST_RE        (Q-A)
#   4) 文件有效性  — drift_file_valid                (AC-B7，镜像 check_file_valid)
#   5) 期望产出清单 — register_expected / scan_missing_expected    (AC-B6)
#   放行窗口      — mark_allowed / is_allowed        (AC-A9，供 Phase 2 用)
#
# 未来引入方（source 本文件）：
#   - post-tool-drift.sh    (PostToolUse, set -euo pipefail)  — Phase 2
#   - pipeline-gate.sh      (PreToolUse, set -euo pipefail)   — Phase 2（扩展现有）
#   - subagent-contract.sh  (SubagentStop)                    — Phase 3
#
# ⚠️ 调用约定（关键，照 status-read.sh L25-32）:
#   在 `set -euo pipefail` 的 hook 中，本库中「可失败」的函数（read_counter /
#   is_build_test_cmd / drift_file_valid / is_allowed / scan_missing_expected / bump_or_reset）
#   **绝不能裸调用**，必须用 `if fn; then ... else ...; fi` 或 `fn || { ... }` 包裹。
#   在 `if`/`||`/`&&` 上下文中调用时，bash 会在函数体内临时禁用 set -e，
#   因此函数内部中间命令（grep/jq 无匹配等）失败不会误杀调用方。
#
# 成功/失败路径都给全部导出变量赋值（含 // 默认值），避免调用方 set -u 触发 unbound。
# 库内部所有 grep/正则匹配写在 if 条件内，绝不裸调用。
#
# /tmp 状态文件（固定命名，设计 §核心实体）:
#   /tmp/.trae-drift-cmd-counter          — JSON: count/fingerprint/last_exit/updated_at/session_id
#   /tmp/.trae-drift-cmd-allowed          — 放行时刻 Unix 时间戳（照搬 command-guard-allowed 模式）
#   /tmp/.trae-drift-expected-outputs.jsonl — 期望产出登记（append-only, jsonl）
# ============================================

# ── 常量 ──
DRIFT_COUNTER_FILE="${DRIFT_COUNTER_FILE:-/tmp/.trae-drift-cmd-counter}"
DRIFT_ALLOWED_FILE="${DRIFT_ALLOWED_FILE:-/tmp/.trae-drift-cmd-allowed}"
DRIFT_EXPECTED_FILE="${DRIFT_EXPECTED_FILE:-/tmp/.trae-drift-expected-outputs.jsonl}"
DRIFT_THRESHOLD="${DRIFT_THRESHOLD:-3}"        # Q-2：连续同类失败达到该值触发熔断（可调）
DRIFT_ALLOW_WINDOW="${DRIFT_ALLOW_WINDOW:-300}" # AC-A9：放行窗口秒数（照搬 300s 模式）
export DRIFT_COUNTER_FILE DRIFT_ALLOWED_FILE DRIFT_EXPECTED_FILE DRIFT_THRESHOLD DRIFT_ALLOW_WINDOW

# 构建/测试命令白名单正则（Q-A）。
# ⚠️ 命令位置锚定（MUST-FIX 修复，loop_count=1）：正则以 `^` 锚定到「片段起始」，
# 只匹配**命令位置的可执行名**（第一个 token）。绝不用 `[[:space:]]` 作为前缀锚点，
# 否则参数位的构建词（`echo make` / `cat build.log` / `ls test/`）会假阳性。
# 片段切分 + env 前缀剥离由 is_build_test_cmd 负责，本正则只对「已剥离的单个片段」判定。
# 命中：make / cmake / npm|pnpm|yarn|cargo <任意子命令> / go (build|test|run|vet) /
#       pytest / jest / vitest / tsc / gcc|g++|clang|rustc / mvn|gradle|ctest|bazel /
#       python[3] -m (pytest|unittest) / dotnet (build|test)。
# 不命中：grep / test / diff / ls / makeup（词边界，`([[:space:]]|$)` 收尾）/ gccversion。
CMD_BUILD_TEST_RE="${CMD_BUILD_TEST_RE:-^(make|cmake|npm|pnpm|yarn|cargo|go[[:space:]]+(build|test|run|vet)|mvn|gradle|pytest|jest|vitest|tsc|gcc|g\+\+|clang|rustc|python[3]?[[:space:]]+-m[[:space:]]+(pytest|unittest)|ctest|bazel|dotnet[[:space:]]+(build|test))([[:space:]]|$)}"
export CMD_BUILD_TEST_RE

# ============================================
# is_build_test_cmd <cmd>   (Q-A)
# ============================================
# 命中构建/测试白名单 → return 0；否则 return 1（不计数类）。
#
# ⚠️ MUST-FIX 修复（loop_count=1）：旧实现直接对整条命令串做正则匹配，且正则前缀锚点
# 为 `[;&|[:space:]]`，导致「构建词出现在参数位」的命令（`echo make`、`cat build.log`、
# `ls test/`、`grep make file`）被假阳性判为构建命令，污染 Phase 2 漂移计数（违反 AC-A7）。
# 修复：只在构建/测试工具出现在**命令位置**（片段的第一个 token）时才命中。
#
# 判定流程：
#   1) 按复合分隔符（&& || ; | &）把命令串切成多个片段；
#   2) 逐片段剥离前导空白 + env 赋值前缀（如 `FOO=bar make` → `make`）；
#   3) 对剥离后的片段头部用命令位置锚定正则 CMD_BUILD_TEST_RE（`^...`）匹配；
#   4) 任一片段的**命令位**命中 → return 0（覆盖 `cd x && make` 这类复合命令中的真命令）。
# 纯字符串/正则判定，无副作用。可失败函数：调用方需 `if is_build_test_cmd "$c"; then`。
is_build_test_cmd() {
    local cmd="${1:-}"
    if [ -z "$cmd" ]; then
        return 1
    fi

    # (1) 按复合分隔符切片段。&& / || 先于单字符 &|; 被 ERE 最左匹配吞掉。
    #     换行也当分隔符（多行命令）。切分后逐行处理。
    local segments seg
    segments=$(printf '%s\n' "$cmd" | sed -E 's/(\&\&|\|\||[;|&])/\n/g')

    while IFS= read -r seg; do
        # (2a) 去前导空白
        seg="${seg#"${seg%%[![:space:]]*}"}"
        [ -z "$seg" ] && continue

        # (2b) 循环剥离 env 赋值前缀：VAR=value（value 不含空白），后跟至少一个空白。
        #      支持连续多个（A=1 B=2 make）。剥离后再去前导空白。
        while [[ "$seg" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+ ]]; do
            seg="${seg#*[[:space:]]}"
            seg="${seg#"${seg%%[![:space:]]*}"}"
        done
        [ -z "$seg" ] && continue

        # (3) 命令位锚定匹配（正则以 ^ 起始，只看片段头部的可执行名）。
        if [[ "$seg" =~ $CMD_BUILD_TEST_RE ]]; then
            return 0
        fi
    done <<< "$segments"

    return 1
}

# ============================================
# compute_fingerprint <err_text>   (AC-A2 / AC-A7 部分)
# ============================================
# 从错误输出计算归一化短 hash。归一化剔除：行号/数字、时间戳、绝对/相对路径的目录段，
# **以及路径末段 basename**（repo-exploration §7 指纹发现：设计原正则 `s#/[^ ]+/##g`
# 只剔目录不剔 basename，会导致仅文件名不同的同类错误产出不同指纹 —— 此处扩展归一化，
# 把 `dir/dir/name.ext` 整体路径 token 全部剔除，实现 basename 不敏感的「同类」匹配）。
#
# 归一化步骤（顺序有意义）：
#   1) 十六进制内存地址/哈希（0x... 或裸 hex 串）→ 剔除，避免地址噪声
#   2) 路径 token（含至少一个 `/` 的连续非空白串，覆盖 dir + basename）→ 整体剔除
#   3) 所有数字（行号/列号/错误码数字/时间戳数字）→ 剔除
#   4) 折叠多余空白 → 单空格
#   取前 20 行关键错误 → cksum 短 hash（工具已确认可用，无外部依赖）。
#
# AC-A7：错误文本为空/归一化后为空 → 回显固定「不可判定」标记 __DRIFT_FP_UNDECIDABLE__
#        并 return 1，供上层识别「不可判定」，不诱导硬阻断。可判定 → 回显 hash + return 0。
compute_fingerprint() {
    local err_text="${1:-}"

    # AC-A7：空输入 → 不可判定
    if [ -z "$err_text" ]; then
        echo "__DRIFT_FP_UNDECIDABLE__"
        return 1
    fi

    local normalized
    normalized=$(printf '%s\n' "$err_text" \
        | sed -E 's/0[xX][0-9a-fA-F]+//g;                # 1) 十六进制地址
                   s#[^[:space:]]*/[^[:space:]]*##g;     # 2) 路径 token（dir + basename 全剔）
                   s/[0-9]+//g;                          # 3) 数字/行号/时间戳
                   s/[[:space:]]+/ /g' \
        | head -20 2>/dev/null || true)

    # 去除首尾空白后判断是否归一化到空 → 不可判定（AC-A7）
    local trimmed
    trimmed=$(printf '%s' "$normalized" | tr -d '[:space:]')
    if [ -z "$trimmed" ]; then
        echo "__DRIFT_FP_UNDECIDABLE__"
        return 1
    fi

    local fp
    fp=$(printf '%s' "$normalized" | cksum 2>/dev/null | awk '{print $1}' 2>/dev/null || true)
    if [ -z "$fp" ]; then
        echo "__DRIFT_FP_UNDECIDABLE__"
        return 1
    fi
    echo "$fp"
    return 0
}

# ============================================
# read_counter   (AC-A3 / A10)
# ============================================
# 读 /tmp/.trae-drift-cmd-counter → 导出 DC_COUNT / DC_FP / DC_EXIT / DC_SID / DC_UPDATED。
# 成功读取 return 0；文件缺失/损坏 return 1。**两种路径都赋全部默认值**（避免 set -u unbound）。
# 可失败函数：调用方需 `read_counter || true` 或 `if read_counter; then`。
read_counter() {
    # 先赋默认值（无论成败调用方都能安全引用）
    DC_COUNT=0
    DC_FP=""
    DC_EXIT=0
    DC_SID=""
    DC_UPDATED=0
    export DC_COUNT DC_FP DC_EXIT DC_SID DC_UPDATED

    if [ ! -f "$DRIFT_COUNTER_FILE" ]; then
        return 1
    fi
    if ! jq empty "$DRIFT_COUNTER_FILE" 2>/dev/null; then
        return 1
    fi

    DC_COUNT=$(jq -r '.count // 0' "$DRIFT_COUNTER_FILE" 2>/dev/null || echo 0)
    DC_FP=$(jq -r '.fingerprint // ""' "$DRIFT_COUNTER_FILE" 2>/dev/null || echo "")
    DC_EXIT=$(jq -r '.last_exit // 0' "$DRIFT_COUNTER_FILE" 2>/dev/null || echo 0)
    DC_SID=$(jq -r '.session_id // ""' "$DRIFT_COUNTER_FILE" 2>/dev/null || echo "")
    DC_UPDATED=$(jq -r '.updated_at // 0' "$DRIFT_COUNTER_FILE" 2>/dev/null || echo 0)
    export DC_COUNT DC_FP DC_EXIT DC_SID DC_UPDATED
    return 0
}

# 内部：原子写计数文件（写临时文件再 mv，规避 read-modify-write 竞态，repo-exploration §7）
_drift_write_counter() {
    local count="$1" fp="$2" last_exit="$3" sid="$4"
    local now tmp
    now=$(date +%s 2>/dev/null || echo 0)
    tmp="${DRIFT_COUNTER_FILE}.$$.tmp"
    if jq -n \
        --argjson count "$count" \
        --arg fp "$fp" \
        --argjson last_exit "$last_exit" \
        --arg sid "$sid" \
        --argjson updated_at "$now" \
        '{count:$count, fingerprint:$fp, last_exit:$last_exit, last_cmd_class:"build-test", updated_at:$updated_at, session_id:$sid}' \
        > "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$DRIFT_COUNTER_FILE" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
        return 0
    fi
    rm -f "$tmp" 2>/dev/null || true
    return 1
}

# ============================================
# bump_or_reset <exit_code> <fingerprint> <session_id>   (AC-A3 / A6)
# ============================================
# 规则：
#   - exit_code == 0（成功）           → 清零计数（reset_counter），导出 DC_COUNT=0，return 0
#   - 非零 + 同 session + 同指纹       → count+1（同类累加），return 0
#   - 非零 + 异类（session 或指纹不同）→ 重置为 1 并换指纹/session（AC-A6），return 0
# 写入后导出最新 DC_COUNT/DC_FP/... 供调用方直接判断阈值。
# 可失败函数：调用方需包裹。参数缺失 return 1。
bump_or_reset() {
    local exit_code="${1:-}"
    local fp="${2:-}"
    local sid="${3:-}"

    if [ -z "$exit_code" ]; then
        return 1
    fi

    # 成功 → 清零（AC-A6）
    if [ "$exit_code" -eq 0 ] 2>/dev/null; then
        reset_counter || true
        return 0
    fi

    # 读当前计数（缺失时得到默认 count=0）
    read_counter || true

    # ── SF-1 修复：session_id 缺失时降级为 fingerprint-only 计数 ──
    # 同类判定分两层：
    #   1) 指纹必须一致（核心归类依据，不可降级）；
    #   2) session 隔离是「加分项」——仅当当前 sid 与已存 sid **两者都非空**时才要求相等；
    #      任一为空（拿不到 session_id）→ 降级：不因缺 sid 就判异类/重置为 1。
    # 这样即使真实环境完全提取不到 session_id，只要指纹一致仍能累加到阈值触发熔断，
    # 修复「缺 sid → count 恒卡 1、熔断静默失效」（verifier V7b/V7c 复现的主路径缺陷）。
    local fp_match=1 sid_match=1
    if [ -z "$fp" ] || [ "$fp" != "$DC_FP" ]; then
        fp_match=0
    fi
    # 仅当双方 sid 都非空且不相等时，才视为跨会话（判异类）；缺 sid 一侧则降级放行。
    if [ -n "$sid" ] && [ -n "$DC_SID" ] && [ "$sid" != "$DC_SID" ]; then
        sid_match=0
    fi

    local new_count
    if [ "$fp_match" -eq 1 ] && [ "$sid_match" -eq 1 ]; then
        # 同类：指纹一致 + 未检出跨会话（含缺 sid 降级）→ 累加
        new_count=$((DC_COUNT + 1))
    else
        # 异类（指纹变化 / 明确跨会话 / 首次）→ 重置为 1 并换指纹/session（AC-A6）
        new_count=1
    fi

    if _drift_write_counter "$new_count" "$fp" "$exit_code" "$sid"; then
        DC_COUNT="$new_count"
        DC_FP="$fp"
        DC_EXIT="$exit_code"
        DC_SID="$sid"
        export DC_COUNT DC_FP DC_EXIT DC_SID
        return 0
    fi
    return 1
}

# ============================================
# reset_counter   (AC-A6)
# ============================================
# 清零计数文件（成功 / 放行 / session 切换 / 超时陈旧时调用）。删除状态文件即视为清零。
# 导出 DC_COUNT=0 等默认值。始终 return 0。
reset_counter() {
    rm -f "$DRIFT_COUNTER_FILE" 2>/dev/null || true
    DC_COUNT=0
    DC_FP=""
    DC_EXIT=0
    DC_SID=""
    DC_UPDATED=0
    export DC_COUNT DC_FP DC_EXIT DC_SID DC_UPDATED
    return 0
}

# ============================================
# root_cause_guidance <count> <threshold> <cmd>   (AC-A8 / SF-3)
# ============================================
# 输出统一的漂移根因指引文案（单一维护点）。PostToolUse(post-tool-drift.sh) 达阈软注入
# 与 PreToolUse(pipeline-gate.sh) 达阈 ask 弹窗**共用**本函数，避免两处文案内联发散
# （SF-3 修复）。调用方可在返回文本后按需追加自己的差异行（如 pre 侧的「点允许放行」提示）。
# 纯输出函数（cat heredoc），无可失败中间命令，set -euo pipefail 下可安全 $() 捕获。
root_cause_guidance() {
    local count="${1:-?}"
    local threshold="${2:-$DRIFT_THRESHOLD}"
    local cmd="${3:-}"
    cat <<EOF
🛑 命令漂移熔断：同一类构建/测试命令已连续失败 ${count} 次（阈值 ${threshold}，失败指纹一致）。

请立即停止「换个写法再试一次」的试错循环——继续盲试只会重复同一个根因错误。改为：
  1. 完整重读最近一次的错误输出，定位真正的根因（依赖缺失？路径错误？语法/类型错误？配置不符？）；
  2. 重读相关源文件、构建配置（如 package.json / Makefile / CMakeLists / tsconfig / Cargo.toml）与本 Phase 的 spec.md / repo-exploration.md，确认前提假设是否成立；
  3. 若根因仍不明，向用户/上游说明卡点，不要继续以同一方式反复执行。

失败命令：${cmd}
EOF
}

# ============================================
# mark_allowed   (AC-A9)
# ============================================
# 写放行时刻 Unix 时间戳到 /tmp/.trae-drift-cmd-allowed（照搬 command-guard-allowed 模式）。
mark_allowed() {
    date +%s > "$DRIFT_ALLOWED_FILE" 2>/dev/null || true
    return 0
}

# ============================================
# is_allowed   (AC-A9)
# ============================================
# 放行标记存在且 now - ts < DRIFT_ALLOW_WINDOW(300s) → return 0（在放行窗口内）；否则 return 1。
# stat -c %Y 写法照搬 pipeline-gate.sh L186。可失败函数：调用方需包裹。
is_allowed() {
    if [ -f "$DRIFT_ALLOWED_FILE" ] && \
       [ $(($(date +%s) - $(stat -c %Y "$DRIFT_ALLOWED_FILE" 2>/dev/null || echo 0))) -lt "$DRIFT_ALLOW_WINDOW" ]; then
        return 0
    fi
    return 1
}

# ============================================
# drift_file_valid <file> [min_lines] [marker]   (AC-B7)
# ============================================
# 与 pipeline-gate.sh check_file_valid (L98-119) **完全一致**的语义：
#   存在 + 行数 >= min_lines(默认 5) + （若给定 marker）含该标记。
# 不引入第二套判定逻辑。可失败函数：调用方需 `if drift_file_valid ...; then`。
drift_file_valid() {
    local FILE="${1:-}"
    local MIN_LINES="${2:-5}"
    local REQUIRED_MARKER="${3:-}"

    if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
        return 1
    fi
    local LINE_COUNT
    LINE_COUNT=$(wc -l < "$FILE" 2>/dev/null || echo "0")
    if [ "$LINE_COUNT" -lt "$MIN_LINES" ]; then
        return 1
    fi
    if [ -n "$REQUIRED_MARKER" ]; then
        if ! grep -q "$REQUIRED_MARKER" "$FILE" 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

# ============================================
# register_expected <agent> <file> <session_id>   (AC-B6)
# ============================================
# append 一行 JSON 到 /tmp/.trae-drift-expected-outputs.jsonl（登记子 agent 期望产出）。
# checked 初始为 false。参数缺失 return 1；成功 return 0。
register_expected() {
    local agent="${1:-}"
    local file="${2:-}"
    local sid="${3:-}"

    if [ -z "$agent" ] || [ -z "$file" ]; then
        return 1
    fi

    local now line
    now=$(date +%s 2>/dev/null || echo 0)
    if line=$(jq -cn \
        --arg agent "$agent" \
        --arg expected "$file" \
        --argjson dispatched_at "$now" \
        --arg sid "$sid" \
        '{agent:$agent, expected:$expected, dispatched_at:$dispatched_at, session_id:$sid, checked:false}' 2>/dev/null); then
        printf '%s\n' "$line" >> "$DRIFT_EXPECTED_FILE" 2>/dev/null || return 1
        return 0
    fi
    return 1
}

# ============================================
# scan_missing_expected <session_id>   (AC-B6)
# ============================================
# 读 expected-outputs.jsonl，回显该 session 下「checked=false 且期望文件缺失/无效」的条目
# （每行一条 JSON），供 SubagentStop 逐条 block。
# 有缺失条目 → 逐行回显 + return 0；无清单/无缺失 → 无输出 + return 1（可失败，需包裹）。
scan_missing_expected() {
    local sid="${1:-}"

    if [ ! -f "$DRIFT_EXPECTED_FILE" ]; then
        return 1
    fi

    local found=1
    local row expected checked row_sid
    # 逐行读，避免 jq 一次性加载全文；每行独立解析
    while IFS= read -r row; do
        [ -z "$row" ] && continue
        # 无效 JSON 行跳过（不误杀）
        if ! printf '%s' "$row" | jq empty 2>/dev/null; then
            continue
        fi
        row_sid=$(printf '%s' "$row" | jq -r '.session_id // ""' 2>/dev/null || echo "")
        # session 过滤：给定 sid 时只看同 session；未给定则全看
        if [ -n "$sid" ] && [ "$row_sid" != "$sid" ]; then
            continue
        fi
        checked=$(printf '%s' "$row" | jq -r '.checked // false' 2>/dev/null || echo "false")
        if [ "$checked" = "true" ]; then
            continue
        fi
        expected=$(printf '%s' "$row" | jq -r '.expected // ""' 2>/dev/null || echo "")
        # 期望文件缺失或无效（复用 drift_file_valid，min_lines=1 仅判存在非空）
        if ! drift_file_valid "$expected" 1; then
            printf '%s\n' "$row"
            found=0
        fi
    done < "$DRIFT_EXPECTED_FILE"

    return "$found"
}
