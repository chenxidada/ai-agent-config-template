#!/bin/bash
# ============================================
# lib/status-read.sh — 共享恢复辅助库 (sourced，非独立执行)
# ============================================
# 供四个 hook 通过 `source` 引入的共享库，包含两类职责：
#   1) read_status          — 状态读取逻辑收敛于一处（四步校验 + fail-loud）
#   2) emit_anchoring_block  — 输出流程与角色锚定块（Phase 1 Core A）
#
# 引入方（source 本文件）：
#   - session-recovery.sh   (SessionStart) — read_status + emit_anchoring_block
#   - context-snapshot.sh   (Stop) — read_status + emit_anchoring_block
#   - pipeline-advance.sh   (Stop, set -euo pipefail) — read_status
#   - pipeline-gate.sh      (PreToolUse, set -euo pipefail) — read_status
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

# ============================================
# emit_anchoring_block <current_stage>
# ============================================
# Phase 1 Core A：输出「流程与角色锚定块」到 stdout。
# 由 session-recovery.sh（注入）与 context-snapshot.sh（写入 recovery-instructions.md）
# 共同调用，确保两处锚定内容逐字一致（AC-A4），并集中维护、杜绝漂移。
#
# 只输出锚定文本，不读状态、不产生副作用；调用方须先 read_status 成功后再调用。
# 静态部分用带引号 heredoc（<<'ANCHOR'）→ 字面反引号/$ 无需转义、绝不做变量展开。
# 阶段化「该做/不能做」用 case 按 $1 分支，含 *) 默认兜底（AC-A3）。
#
# 覆盖：AC-A1 强制读指令 / AC-A2 三条铁律 / AC-A3 阶段化提示 / AC-A5 权威声明。
emit_anchoring_block() {
    local stage="${1:-}"

    cat <<'ANCHOR'

---

## 🔒 流程与角色锚定（恢复后必读，优先于任何操作）

> ⚠️ 强制第 0 步：在执行任何流程动作（委托子 Agent、推进 Human Gate、切换阶段）之前，
> **必须先用 Read 工具完整读取 `.trae/rules/spec-workflow.md`**（always-applied 权威流程规则，含全部命令定义）。
> 未读取该文件前，不得委托任何子 Agent、不得推进任何 Human Gate。

### 你的角色三条铁律（复述并遵守）

1. **不实施 / 不审查 / 不验证（只委托）** — 你是 TRAE Agent，担任**调度者**：讨论需求 → 设计方案 → 委托子 Agent 执行 → 等待用户确认。你不自己写实现代码（委托 implementer）、不自己审查代码（委托 reviewer）、不自己运行验证（委托 verifier）。
2. **Human Gate 不可跳** — HG-1 需求确认 / HG-2 方案确认 / HG-3 Phase 完成确认，三个节点必须停下等待用户**明确确认**（如「确认」「开始实施」「验收通过」）；禁止跳过 Human Gate 直接委托下一阶段子 Agent；用户说「看看」「好的」等模糊回复不算通过。
3. **Phase ID 来自 DAG JSON、禁止自编** — current_phase 必须原样取自 `phase-plan.md` 中 DAG JSON 的 `phases[].id`，任何 Agent 或调度者都不得自己另起名字。

### 下一步如何确定流程

- 参照 `spec-workflow.md` 的「可用命令」表与「工作流阶段定义」来判断当前应委托哪个子 Agent、下一步是什么。
- **不依赖** `current-status.json` 中的 `command` 字段（该字段不存在，不要臆造）。

ANCHOR

    # ── AC-A3 阶段化「该做 / 不能做」（case 按 current_stage 分支，含默认兜底）──
    case "$stage" in
        requirement-analysis)
            cat <<'ANCHOR'
### 当前阶段：requirement-analysis（需求分析）

- ✅ 该做：委托 `requirement-analyst` 产出 `requirements.md`；产出后用 5-8 句向用户概括需求，等待 **HG-1** 明确确认。
- ⛔ 不能做：HG-1 未过就委托 `plan-generator` 或进入架构设计；不能自己写需求分析。
ANCHOR
            ;;
        architecture-design)
            cat <<'ANCHOR'
### 当前阶段：architecture-design（架构设计）

- ✅ 该做：委托 `plan-generator` 产出 `design.md` + `phase-plan.md` + 各 phase `spec.md`；产出后向用户展示架构决策 + Phase 拆分，等待 **HG-2** 明确确认。
- ⛔ 不能做：**不能委托 implementer**；HG-2 未过不能进入实施；不能自己设计架构。
ANCHOR
            ;;
        phase-implementation)
            cat <<'ANCHOR'
### 当前阶段：phase-implementation（Phase 实施）

- ✅ 该做：每个 Phase 前**先委托 `code-explorer`** → 建 `impl-<phase-id>` 分支 → 委托 `implementer` → 3 个并行 reviewer → `verifier`；每个 Phase 完成后等待 **HG-3** 验收。current_phase 必须取自 DAG JSON。
- ⛔ 不能做：不能跳过 code-explorer / reviewer / verifier；不能自己写、审、验代码；HG-3 未过不能进入下一 Phase。
ANCHOR
            ;;
        *)
            cat <<'ANCHOR'
### 当前阶段：未识别（default 兜底）

- ⚠️ 当前 `current_stage` 不在预期取值域（requirement-analysis / architecture-design / phase-implementation）内。
- ✅ 该做：先用 Read 读取 `current-status.json` 与 `.trae/rules/spec-workflow.md`，确认真实阶段后再决定委托对象。
- ⛔ 不能做：在阶段未确认前，不要委托任何子 Agent、不要推进任何 Human Gate。
ANCHOR
            ;;
    esac

    # ── AC-A5 权威声明 ──
    cat <<'ANCHOR'

### 权威来源声明

> 以上注入摘要（状态表 + 锚定提示）**仅供参考**。权威运行状态以 `current-status.json` 为准，
> 流程规则以 `.trae/rules/spec-workflow.md` 为准。二者与本摘要不一致时，以这两个文件为准。
ANCHOR
}
