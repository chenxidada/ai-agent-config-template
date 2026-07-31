#!/bin/bash
# ============================================
# lib/status-read.sh — 共享状态读取片段 (sourced，非独立执行)
# ============================================
# 供四个 hook 通过 `source` 引入，实现「状态读取逻辑收敛于一处」：
#   - session-recovery.sh   (SessionStart)
#   - context-snapshot.sh   (Stop)
#   - pipeline-advance.sh   (Stop, set -euo pipefail)
#   - pipeline-gate.sh      (PreToolUse, set -euo pipefail)
#
# read_status "$STATUS_FILE"
#   成功: 导出 CURRENT_STAGE / HG1 / HG2 / HG3 / CURRENT_PHASE / LOOP_COUNT / DESCRIPTION 七个变量, return 0
#   失败: 向 stderr 打印 `STATUS_READ_ERROR: <原因 + 缺失字段名 + 文件路径>`, return 非零
#
# 四步校验:
#   1) 文件存在
#   2) `jq empty` 验证 JSON 合法
#   3) 关键字段存在 (.human_gates 且含 hg1/hg2/hg3；.current_stage)
#   4) 用正确路径 .human_gates.hgN 读值（历史 bug：session-recovery/context-snapshot 曾用顶层 .hgN）
#
# ⚠️ 调用约定（关键）:
#   在 `set -euo pipefail` 的 hook（gate/advance）中，read_status **绝不能裸调用**，
#   必须用 `if read_status "$F"; then ... else ...; fi` 或 `read_status "$F" || { ... }` 包裹，
#   否则读取失败路径会被 set -e 杀死整个 hook。
#   在 `if`/`||`/`&&` 上下文中调用时，bash 会在函数体内临时禁用 set -e，
#   因此函数内部的中间命令失败不会误杀调用方。
#
# 成功路径必定给全部 7 个导出变量赋值（含 // 默认值），避免调用方 set -u 触发 unbound。
# ============================================

read_status() {
    local status_file="${1:-}"

    # ── 步骤 1：文件路径 + 文件存在 ──
    if [ -z "$status_file" ]; then
        echo "STATUS_READ_ERROR: 未提供 STATUS_FILE 路径参数（read_status 第一个参数为空）" >&2
        return 1
    fi
    if [ ! -f "$status_file" ]; then
        echo "STATUS_READ_ERROR: 状态文件不存在: $status_file" >&2
        return 1
    fi

    # ── 步骤 2：jq empty 验证 JSON 合法 ──
    if ! jq empty "$status_file" 2>/dev/null; then
        echo "STATUS_READ_ERROR: 状态文件 JSON 无法被 jq 解析（内容损坏）: $status_file" >&2
        return 1
    fi

    # ── 步骤 3：关键字段存在 ──
    if [ "$(jq 'has("current_stage")' "$status_file" 2>/dev/null)" != "true" ]; then
        echo "STATUS_READ_ERROR: 缺少关键字段 .current_stage: $status_file" >&2
        return 1
    fi
    if [ "$(jq 'has("human_gates")' "$status_file" 2>/dev/null)" != "true" ]; then
        echo "STATUS_READ_ERROR: 缺少关键字段 .human_gates: $status_file" >&2
        return 1
    fi
    local _hg
    for _hg in hg1 hg2 hg3; do
        if [ "$(jq --arg k "$_hg" '.human_gates | has($k)' "$status_file" 2>/dev/null)" != "true" ]; then
            echo "STATUS_READ_ERROR: 缺少关键字段 .human_gates.$_hg: $status_file" >&2
            return 1
        fi
    done

    # ── 步骤 4：用正确路径 .human_gates.hgN 读值并导出（7 个变量全部赋值）──
    CURRENT_STAGE=$(jq -r '.current_stage // "unknown"' "$status_file" 2>/dev/null)
    HG1=$(jq -r '.human_gates.hg1 // "pending"' "$status_file" 2>/dev/null)
    HG2=$(jq -r '.human_gates.hg2 // "pending"' "$status_file" 2>/dev/null)
    HG3=$(jq -r '.human_gates.hg3 // "pending"' "$status_file" 2>/dev/null)
    CURRENT_PHASE=$(jq -r '.current_phase // ""' "$status_file" 2>/dev/null)
    LOOP_COUNT=$(jq -r '.loop_count // 0' "$status_file" 2>/dev/null)
    DESCRIPTION=$(jq -r '.description // ""' "$status_file" 2>/dev/null)
    export CURRENT_STAGE HG1 HG2 HG3 CURRENT_PHASE LOOP_COUNT DESCRIPTION
    return 0
}
