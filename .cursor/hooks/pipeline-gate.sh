#!/bin/bash
# ============================================
# pipeline-gate.sh — Human Gate 程序化门禁 v8
# 绑定: preToolUse (matcher: Task + Edit + Write)
# schema: .specdev/specs/{slug}/current-status.json
# failClosed: true — hook 崩溃 = deny
#
# ── v8 变更要点（相对 v7）──
# 1. 删除心跳机制：它只在 allow 消息上附提醒、永不阻断，属纯噪声，
#    且每次工具调用写 /tmp 全局文件（跨会话污染）。deny 路径反而是黑的 —— 零价值。
# 2. 输出原语收敛到 lib/emit.sh：替换 26 处手写 JSON 字面量（最大漂移点）。
# 3. fail-closed 化：所有「无法判定」走 gate_unknown()，活跃工作流期间一律 deny。
#    此前 11 处 `return 0` / `|| echo default` 让门禁静默放行（详见各处 ⚠️ 注释）。
# 4. hg3 的 verifier 判决校验由 `ask` 改为 `deny`：
#    ⚠️ 官方文档明确 `"ask"` **被 preToolUse 接受但不执行**（等同 allow），
#    故原 AC-14/15/16 三处 ask 实为空操作 —— 这是本文件此前最大的漏洞。
# 5. 项目根改用 workspace_roots[0]：
#    ⚠️ 实测（Cursor 3.9.16）preToolUse 的 `.cwd` 字段存在但恒为空字符串，不可用。
# 6. 判决判定改为「自陈 + 证据」双判：review.md 自陈 PASS 但 Must-Fix 区
#    实测有 🔴（含 4 份并行 reviewer 原始报告）时仍 deny。
#
# ── 硬阻断清单（程序化，不依赖模型自觉）──
#   · HG-1/1.5/2 未过 → 不放行下游 Agent
#   · 阶段不一致（非 phase-implementation）→ 不放行实施类 Agent
#   · current_phase 必须 ∈ phase-plan.md DAG JSON 的 phases[].id
#   · 实施类 Agent 必须位于 impl-<current_phase> 分支
#   · repo-exploration.md 未产出 → 不放行 implementer
#   · design.md 缺「现状依据」或证据指向不存在的位置 → 不放行 hg2（L1–L5）
#   · UI Phase 缺 ui-spec.md / visual-baseline.md → 不放行 implementer
#   · UI Phase 原型未确认（.prototype-approved 缺失）→ 不放行 reviewer/verifier
#   · review.md 判决 MUST-FIX 或 Must-Fix 区有 🔴 → 不放行 verifier / hg3
#   · verifier 判决非 PASS / 缺判决 / 与残余风险自相矛盾 → 不放行 hg3
#   · implementer loop_count >= 2 或 verifier_loop_count >= 2 → 硬停，逼用户介入
# ============================================

# ── source 共享库（路径绝对化，须在任何 cd 之前）──
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/status-read.sh
source "$HOOK_DIR/lib/status-read.sh"
# shellcheck source=lib/verdict-parse.sh
source "$HOOK_DIR/lib/verdict-parse.sh"
# shellcheck source=lib/emit.sh
source "$HOOK_DIR/lib/emit.sh"

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# ── 项目根 ──
# ⚠️ 实测：preToolUse 的 `.cwd` 字段存在但**恒为空字符串**，不可作路径基准。
# workspace_roots[0] 是唯一可靠来源；再退化为 HOOK_DIR/../..（本脚本位于 <root>/.cursor/hooks/）。
PROJECT_ROOT=$(printf '%s' "$INPUT" | jq -r '.workspace_roots[0] // empty' 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
fi

ACTIVE_FILE="$PROJECT_ROOT/.specdev/active-workflow"
WORKFLOW_ACTIVE=0
if [ -f "$ACTIVE_FILE" ]; then
    WORKFLOW_ACTIVE=1
fi

# project_rel <绝对路径> → 相对项目根的展示用路径（仅用于消息可读性）
project_rel() {
    printf '%s' "${1#"$PROJECT_ROOT"/}"
}

# ============================================================
# 辅助函数（必须在任何分支之前定义 —— bash 顺序执行，函数定义是运行时生效的）
# ============================================================

# ── 统一「无法判定」出口（fail-closed 的核心）──
# 语义：活跃工作流期间，「读不出来」是**故障**而非放行理由。
#       没有活跃工作流时（日常写代码）门禁本就无关 → allow，避免卡住正常开发。
# ⚠️ 本函数**必定终止脚本**（emit_* 内部 exit 0）。
gate_unknown() {
    if [ "$WORKFLOW_ACTIVE" != "1" ]; then
        emit_allow
    fi
    emit_deny "⛔ 门禁无法完成判定：${1}"
}

# ── 内容完整性检查 ──
check_file_valid() {
    local FILE="$1"
    local MIN_LINES="${2:-5}"
    local REQUIRED_MARKER="${3:-}"

    if [ ! -f "$FILE" ]; then
        return 1
    fi
    local LINE_COUNT
    LINE_COUNT=$(wc -l < "$FILE" 2>/dev/null || printf '0')
    case "$LINE_COUNT" in
        ''|*[!0-9]*) LINE_COUNT=0 ;;
    esac
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

# ── design.md「现状依据」校验（L1–L5，v8.4 新增）──
# 为什么存在：plan-generator 的 Input 原本不含任何代码库信息，架构决策只能凭空生成。
# 但「不许猜」是不可验收的主观纪律 —— 本项目的经验是「写在文档里的纪律等于没有纪律」。
# 故把它变成可判定的形式：设计必须列出它依赖的现状事实，每条给出 `路径:行号` 证据。
#
# 级别：
#   L1 `## 现状依据` 章节存在
#   L2 章节内至少 MIN_ROWS 条证据
#   L3 每条形态为 `路径:行号`
#   L4 路径在仓库中真实存在（PROJECT_ROOT 或 spec 目录下）
#   L5 行号 <= 该文件实际行数
#
# ⚠️ 边界（必须在代码里写清，否则会重演「以为有保护」）：
#    本函数保证 **「证据指向真实位置」**，不保证 **「证据支持该断言」**。
#    后者是语义判断，属 reviewer-design 的职责 —— 门禁做不到，也永远不该假装能做到。
#
# ⚠️ 逃生舱：显式声明「本设计不依赖现有代码」→ 跳过 L2–L5。
#    「无依据」必须是一个**显式声明**而非沉默默认 —— 与 ui_relevant:false 必须写理由同理。
#
# ⚠️ 实现约束：不得用 `grep -P`（PCRE 是 GNU 扩展，BSD grep 会以退出码 2 失败，
#    在 if 结构中表现为静默反向放行）。一律 -E / sed / awk。
check_design_evidence() {
    local FILE="$1"
    local MIN_ROWS="${2:-1}"

    # L1：章节存在
    local SECTION
    SECTION=$(awk '/^##[[:space:]]*现状依据/{f=1;next} f && /^##[[:space:]]/{exit} f' "$FILE" 2>/dev/null)
    if [ -z "$SECTION" ]; then
        emit_deny "⛔ 设计缺少「现状依据」章节：$(project_rel "$FILE") 必须包含 \`## 现状依据\`，逐条列出本设计依赖的现有代码事实及其证据（形如 \`src/x.ts:42\`）。若本设计确实不依赖任何现有代码，必须显式写出「本设计不依赖现有代码：<理由>」——「无依据」必须留痕，不能是沉默默认。"
    fi

    # 逃生舱：显式声明不依赖现有代码
    if printf '%s' "$SECTION" | grep -qE '本设计不依赖现有代码' 2>/dev/null; then
        return 0
    fi

    # L3：抽取 evidence token（反引号包裹的 `path:line`）
    local EVIDENCE
    EVIDENCE=$(printf '%s' "$SECTION" | grep -oE '`[^`]*:[0-9]+`' 2>/dev/null | tr -d '`')

    # L2：条数
    local COUNT
    COUNT=$(printf '%s\n' "$EVIDENCE" | grep -c '[^[:space:]]' 2>/dev/null)
    case "$COUNT" in ''|*[!0-9]*) COUNT=0 ;; esac
    if [ "$COUNT" -lt "$MIN_ROWS" ]; then
        emit_deny "⛔ 「现状依据」章节无有效证据：$(project_rel "$FILE") 的该章节内未找到任何形如 \`路径:行号\` 的证据条目（至少需要 ${MIN_ROWS} 条）。注意：散文式描述（「现有架构大致是…」）不是证据。"
    fi

    # L4 + L5：逐条核验真实性
    # ⚠️ 用 here-string 而非管道：管道会创建子 shell，里面的 emit_deny 只能退出子 shell，
    #    门禁将带 0 退出码继续执行 → 静默放行。
    local entry p ln target actual
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        p="${entry%:*}"
        ln="${entry##*:}"
        [ -z "$p" ] && continue

        # 路径解析：先 PROJECT_ROOT 相对，再 spec 目录相对（两者都是真实位置）
        target=""
        if [ -e "$PROJECT_ROOT/$p" ]; then
            target="$PROJECT_ROOT/$p"
        elif [ -e "$SPEC_DIR/$p" ]; then
            target="$SPEC_DIR/$p"
        fi

        # L4
        if [ -z "$target" ]; then
            emit_deny "⛔ 「现状依据」含不存在的路径：\`${p}\` （在 $(project_rel "$FILE") 中作为证据引用）。门禁会核验每条证据指向的位置是否真实存在 —— 请改为真实路径，或删除该条断言。"
        fi

        # L5（仅对普通文件；目录无行号概念）
        if [ -f "$target" ]; then
            actual=$(wc -l < "$target" 2>/dev/null || printf '0')
            case "$actual" in ''|*[!0-9]*) actual=0 ;; esac
            if [ "$ln" -gt "$actual" ]; then
                emit_deny "⛔ 「现状依据」行号越界：\`${p}:${ln}\` 指向 $(project_rel "$target")，但该文件只有 ${actual} 行。请核对行号。"
            fi
        fi
    done <<< "$EVIDENCE"

    return 0
}

# ── 读取 phase-plan.md 的 DAG JSON（唯一真相源）──
# jq 过滤器通过 $1 传入；--arg pid 恒注入当前 Phase（不用的过滤器忽略它）。
_read_dag() {
    local DAG_FILE="$SPEC_DIR/phase-plan.md"
    if [ ! -s "$DAG_FILE" ]; then
        printf '%s' ""
        return 0
    fi
    sed -n '/```json/,/```/p' "$DAG_FILE" | grep -v '```' \
        | jq -c --arg pid "$CURRENT_PHASE" "$1" 2>/dev/null | head -1
}

# ── 当前 Phase 的 ui 标记 ──
# 返回 true | false | unknown（三态）。
# ⚠️ v7 只有 true/false，且解析失败返回 false → 静默关闭 UI 门禁
#    （ui-spec / visual-baseline / 原型门禁 / reviewer-visual 校验全部失效）。
read_phase_ui() {
    local out
    out=$(_read_dag '.phases[]? | select(.id == $pid) | .ui')
    case "$out" in
        true)  printf '%s' "true" ;;
        false) printf '%s' "false" ;;
        *)     printf '%s' "unknown" ;;
    esac
}

# ── 本工作流是否存在任一 ui:true 的 Phase ──
read_any_phase_ui() {
    local cnt
    cnt=$(_read_dag '[.phases[]? | select(.ui == true)] | length')
    case "$cnt" in
        ''|*[!0-9]*) printf '%s' "unknown" ;;
        0)           printf '%s' "false" ;;
        *)           printf '%s' "true" ;;
    esac
}

# ── Phase ID 校验（唯一真相源：phase-plan.md 的 DAG JSON phases[].id）──
# ⚠️ v7 在 DAG 缺失 / 解析不出时 `return 0` 放行 → Phase ID 校验可被「删文件」关闭。
validate_phase_id() {
    if [ -z "$CURRENT_PHASE" ]; then
        gate_unknown "current_phase 为空，无法校验 Phase ID。请先完成 Phase 拆分并设置 current_phase。"
    fi

    local DAG_FILE="$SPEC_DIR/phase-plan.md"
    if [ ! -s "$DAG_FILE" ]; then
        gate_unknown "phase-plan.md 缺失或为空：$(project_rel "$DAG_FILE")（Phase ID 的唯一真相源）。"
    fi

    local VALID_IDS
    VALID_IDS=$(sed -n '/```json/,/```/p' "$DAG_FILE" | grep -v '```' | jq -r '.phases[].id' 2>/dev/null)
    if [ -z "$VALID_IDS" ]; then
        gate_unknown "无法从 phase-plan.md 解析出 DAG JSON 的 phases[].id。请确认存在 \`\`\`json 代码块且含 phases 数组。"
    fi

    if printf '%s' "$VALID_IDS" | grep -qxF "$CURRENT_PHASE" 2>/dev/null; then
        return 0
    fi

    emit_deny "⛔ Phase ID 不合法：\`${CURRENT_PHASE}\` 不在 $(project_rel "$DAG_FILE") 的 DAG JSON 中。有效 ID：$(printf '%s' "$VALID_IDS" | tr '\n' ' ')"
}

# ── UI Phase 原型门禁 ──
# 规则：ui: true 的 Phase，在用户确认原型前不得派发 reviewer / verifier。
# 判定「已确认」的唯一依据 = 调度者在用户确认后创建的 .prototype-approved 标记。
# 非 UI Phase 或 implementer 尚未产出原型 → 放行（不干扰首轮 implementer 派发）。
check_prototype_gate() {
    local UI_FLAG="$1"
    [ "$UI_FLAG" != "true" ] && return 0

    local P_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
    local APPROVED_MARK="$P_DIR/.prototype-approved"
    [ -f "$APPROVED_MARK" ] && return 0

    if [ -f "$P_DIR/implementation.md" ] && grep -q "## Prototype" "$P_DIR/implementation.md" 2>/dev/null; then
        emit_deny "⛔ UI Phase 原型门禁：implementation.md 已含「Prototype」章节，但 .prototype-approved 标记不存在 —— 用户尚未确认视觉方向。请先把原型与截图呈现给用户确认，确认后创建 $(project_rel "$APPROVED_MARK")，再派发 reviewer/verifier。"
    fi
    return 0
}

# ── UI Phase 必读前置：ui 标记三态判定 + 原型门禁 ──
# 供 reviewer / verifier 共用，消除两处重复的三态判定。
require_ui_gates() {
    local PHASE_UI
    PHASE_UI=$(read_phase_ui)
    if [ "$PHASE_UI" = "unknown" ]; then
        gate_unknown "无法判定当前 Phase（${CURRENT_PHASE}）的 ui 标记：phase-plan.md 的 DAG JSON 缺失该字段或解析失败。UI 门禁强度取决于此判定。"
    fi
    check_prototype_gate "$PHASE_UI"
    printf '%s' "$PHASE_UI"
}

# ============================================================
# 分发：本 hook 只处理 Task / Edit / Write
# 命令安全由 shell-guard.sh（beforeShellExecution）承担。
# 注：v7 曾为 Shell 留一条「无条件 allow」分支，同时 hooks.json 又注册了
# matcher:"Shell" → 每个 shell 命令白起一个进程。该注册条目与本分支一并删除。
# ============================================================
case "$TOOL_NAME" in
    Task|Edit|Write) : ;;
    *) emit_allow ;;
esac

# ============================================================
# 分支 A：Edit / Write —— current-status.json 写入的完整流程校验
# ============================================================
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
    TARGET_FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

    # 只校验状态文件；其余写入不在本 hook 职责内
    case "$TARGET_FILE" in
        *current-status.json) : ;;
        *) emit_allow ;;
    esac

    # 状态文件写入必须发生在活跃工作流内（否则是孤儿状态，无法定位 SPEC_DIR）
    if [ "$WORKFLOW_ACTIVE" != "1" ]; then
        emit_deny "⛔ 未检测到活跃工作流（$(project_rel "$ACTIVE_FILE") 不存在），但正在写入 current-status.json。请先用 /feature 或 /bugfix 初始化工作流。"
    fi

    SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
    if [ -z "$SLUG" ]; then
        gate_unknown "active-workflow 为空，无法确定工作流 slug。"
    fi
    SPEC_DIR="$PROJECT_ROOT/.specdev/specs/$SLUG"
    STATUS_FILE="$SPEC_DIR/current-status.json"

    # ── 解析本次写入的内容 ──
    # ⚠️ v7 在解析失败时得到空串，随后所有 `grep -q` 全部为假 → 整段校验静默跳过
    #    （「读不出去」变成了「没发现问题」）。现在解析失败即 deny。
    NEW_CONTENT=$(printf '%s' "$INPUT" | jq -r \
        '.tool_input.content // .tool_input.new_string // .tool_input.new_str // empty' 2>/dev/null)
    if [ -z "$NEW_CONTENT" ]; then
        gate_unknown "无法从 tool_input 解析出写入内容（file_path=$(project_rel "$TARGET_FILE")）。状态文件写入必须先能校验其内容语义，否则本门禁形同虚设。"
    fi

    # ── 内容必须是合法 JSON ──
    # ⚠️ 这是一处**残留的 fail-open**（v7 同样存在，v8 首版未修）：
    #    若 content 非空但**不是合法 JSON**（例如传入的是 diff/片段而非整个文件内容），
    #    下面所有 `grep -qE '"hg3"...'` 都会静默不匹配 → 结论变成「没有推进动作」→ 放行。
    #    「非空但读不懂」与「读不出来」必须同等对待：无法校验 = 不放行。
    #    对 current-status.json 而言 content 必须是整个新文件（实测：StrReplace 亦如此），
    #    因此「不是合法 JSON」一定是异常输入，没有合法的放行场景。
    if ! printf '%s' "$NEW_CONTENT" | jq empty >/dev/null 2>&1; then
        gate_unknown "本次写入 current-status.json 的内容不是合法 JSON（可能是片段而非完整文件）。无法校验其语义。"
    fi

    # ── 本次写入声明的 current_phase ──
    # 必须在「初始化判定」之前解析（初始化校验要用它）。
    NEW_PHASE=$(printf '%s' "$NEW_CONTENT" | jq -r '.current_phase // empty' 2>/dev/null)
    HAS_NEW_PHASE=$(printf '%s' "$NEW_CONTENT" | jq -r 'has("current_phase")' 2>/dev/null)

    # ── 状态文件是否存在：区分「首次初始化」与「增量更新」──
    # ⚠️ v8 首版在这里引入了一个**真实回归**：/feature 的初始化顺序是
    #    ① 建目录 → ② 写 active-workflow → ③ 初始化 current-status.json，
    #    第 ③ 步时状态文件尚不存在 → read_status 必然失败 → 被判定为 deny，
    #    导致**整个工作流无法启动**。v7 用 `if [ -f "$STATUS_FILE" ]` 跳过校验，反而没这个问题。
    # 正确语义：文件不存在 = 初始化路径。初始化本身合法，但必须**严格限定其形状**：
    #    · 不得标记任何 Human Gate 为 passed（无产物可校验却声称通过）
    #    · 不得设置 current_phase（Phase 拆分尚未发生）
    # 其余一律按增量更新校验。
    if [ ! -f "$STATUS_FILE" ]; then
        if printf '%s' "$NEW_CONTENT" | grep -qE '"(hg1|hg2|hg3|hg1_5)"[[:space:]]*:[[:space:]]*"passed"'; then
            emit_deny "⛔ 非法初始化：$(project_rel "$STATUS_FILE") 尚不存在，却尝试标记 Human Gate 为 passed。新工作流初始化时所有 HG 必须为 pending。"
        fi
        if [ -n "$NEW_PHASE" ]; then
            emit_deny "⛔ 非法初始化：$(project_rel "$STATUS_FILE") 尚不存在，却尝试设置 current_phase=\`${NEW_PHASE}\`。Phase 拆分（HG-2）完成后才应设置该字段。"
        fi
        emit_allow
    fi

    # ── 读既有状态 ──
    # ⚠️ v7 在此处读失败会降级为「全 pending + CURRENT_PHASE 空」并继续，
    #    而 hg3 校验整体嵌在 `if [ -n "$CURRENT_PHASE" ]` 内 → 空 phase 时
    #    hg3=passed 可**无任何校验**写入。这是最严重的一处 fail-open。
    # 文件已存在却读不出来 = 状态损坏 → 拒绝（不是初始化，不能沿用上一条的宽松处理）。
    if ! read_status "$STATUS_FILE" 2>/dev/null; then
        gate_unknown "既有状态文件无法解析（JSON 损坏或缺失关键字段）：$(project_rel "$STATUS_FILE")。无法在此基础上校验本次写入的合法性。"
    fi

    # ── verifier 失败回路上限硬阻断 ──
    # 当写的是「推进动作」（hg3=passed 或 current_phase 切换）且 verifier_loop_count >= 2
    # 时 deny，逼用户介入。与判决内容校验隔离。
    VLC=$(printf '%s' "$NEW_CONTENT" | jq -r '.verifier_loop_count // empty' 2>/dev/null)
    if [ -z "$VLC" ]; then
        VLC="$VERIFIER_LOOP_COUNT"
    fi
    case "$VLC" in
        ''|*[!0-9]*) VLC=0 ;;
    esac

    # 生效的 current_phase：本次写入若**显式提供**该字段则以其为准。
    # ⚠️ 必须区分「字段不存在」与「字段存在但为空」：
    #    前者 → 沿用旧值（正常的增量状态写入）；
    #    后者 → 视为非法（把 current_phase 清空 = 破坏状态，不能回落旧值绕过校验）。
    if [ "$HAS_NEW_PHASE" = "true" ]; then
        EFFECTIVE_PHASE="$NEW_PHASE"
    else
        EFFECTIVE_PHASE="$CURRENT_PHASE"
    fi

    # 本次写入若自带 hg3 值，以本次为准（HG-3 通过时通常是 hg3 + current_phase 同一次写入）
    NEW_HG3=$(printf '%s' "$NEW_CONTENT" | jq -r '.human_gates.hg3 // empty' 2>/dev/null)
    EFFECTIVE_HG3="${NEW_HG3:-$HG3}"

    IS_ADVANCE=0
    if printf '%s' "$NEW_CONTENT" | grep -qE '"hg3"[[:space:]]*:[[:space:]]*"passed"'; then
        IS_ADVANCE=1
    elif [ -n "$NEW_PHASE" ] && [ "$NEW_PHASE" != "$CURRENT_PHASE" ]; then
        IS_ADVANCE=1
    fi
    if [ "$IS_ADVANCE" -eq 1 ] && [ "$VLC" -ge 2 ]; then
        emit_deny "⛔ verifier 验证循环已达上限（verifier_loop_count=${VLC} >= 2）。请用户介入决定下一步（修复方向 / 放行 / 重做）。"
    fi

    # 先拦「显式清空 current_phase」：它会让后续所有 Phase 定位失效，属状态破坏。
    # ⚠️ 必须带 `-n "$CURRENT_PHASE"` 前提：把「原本有值的 phase 被清空」与
    #    「本来就还没到 Phase 阶段（如 requirement-analysis 期间写入 current_phase:""）」
    #    区分开 —— 后者是正常状态，拦它会导致规划阶段完全无法写状态。
    if [ "$HAS_NEW_PHASE" = "true" ] && [ -z "$NEW_PHASE" ] && [ -n "$CURRENT_PHASE" ]; then
        emit_deny "⛔ 非法状态写入：本次写入把 current_phase 从 \`${CURRENT_PHASE}\` 显式置为空。current_phase 是 Phase 产物定位的唯一依据，清空会使后续 implementer / reviewer / verifier 全部无法定位。若要结束工作流，请清除 $(project_rel "$ACTIVE_FILE")，而不是清空 current_phase。"
    fi

    # ── 检查是否试图设置 hg3=passed ──
    if printf '%s' "$NEW_CONTENT" | grep -qE '"hg3"[[:space:]]*:[[:space:]]*"passed"'; then
        if [ -z "$EFFECTIVE_PHASE" ]; then
            gate_unknown "尝试标记 hg3=passed，但生效的 current_phase 为空 → 无法定位该 Phase 的产物目录。"
        fi
        PHASE_DIR="$SPEC_DIR/phases/$EFFECTIVE_PHASE"

        check_file_valid "$PHASE_DIR/implementation.md" 10 "##" \
            || emit_deny "⛔ 流程不完整：尝试标记 HG-3 通过，但 implementation.md 不存在或内容无效。必须完成 implementer → reviewer → verifier 完整流程。"
        check_file_valid "$PHASE_DIR/review.md" 5 "判决" \
            || emit_deny "⛔ 流程不完整：尝试标记 HG-3 通过，但 review.md 不存在或缺少「判决」。必须先完成 reviewer 审查。"
        check_file_valid "$PHASE_DIR/verification.md" 5 \
            || emit_deny "⛔ 流程不完整：尝试标记 HG-3 通过，但 verification.md 不存在。必须先完成 verifier 独立验证。"

        # ── 判决判定：自陈 + 证据 双判（证据优先）──
        VERDICT=$(parse_review_verdict "$PHASE_DIR/review.md" || printf '%s' "")
        if [ -z "$VERDICT" ]; then
            emit_deny "⛔ review.md 判决行无法解析。必须是单值判决行，例如「## 判决：PASS」（或 MUST-FIX / SHOULD-FIX）：不得加粗、不得追加说明、不得保留多值枚举。"
        fi

        # 证据计数：合并报告 + 4 份并行 reviewer 原始报告（防止合并时丢失 MUST-FIX）
        BLOCKING=0
        for _f in "$PHASE_DIR/review.md" \
                  "$PHASE_DIR/review-correctness.md" \
                  "$PHASE_DIR/review-design.md" \
                  "$PHASE_DIR/review-connectivity.md" \
                  "$PHASE_DIR/review-visual.md"; do
            if [ -f "$_f" ]; then
                _n=$(count_blocking_findings "$_f")
                case "$_n" in ''|*[!0-9]*) _n=0 ;; esac
                BLOCKING=$(( BLOCKING + _n ))
            fi
        done

        if [ "$VERDICT" = "MUST-FIX" ] || [ "$BLOCKING" -gt 0 ]; then
            emit_deny "⛔ 审查未通过，不能标记 HG-3 通过：review.md 自陈判决=${VERDICT}，Must-Fix 区实测阻塞项=${BLOCKING} 条（含 4 份并行报告）。请先修复并重新审查。"
        fi

        # ── verifier 判决校验（deny，不再用 ask）──
        # ⚠️ 为何是 deny 而非 ask：官方文档明确 `"ask"` 在 preToolUse 上
        #    「accepted by the schema but not enforced」→ 等同 allow。
        #    死代码比没有代码更危险：它让人以为有保护。
        VERI_FILE="$PHASE_DIR/verification.md"
        V_VERDICT=$(parse_verdict "$VERI_FILE" || printf '%s' "")
        if [ -z "$V_VERDICT" ]; then
            emit_deny "⛔ verification.md 无可解析判决：必须含单值判决行「## 判决：PASS」（或 PARTIAL / FAIL）。verifier 必须报告单一判决值。"
        fi
        if [ "$V_VERDICT" != "PASS" ]; then
            emit_deny "⛔ verifier 判决为 ${V_VERDICT}（非 PASS）。${V_VERDICT} 表示验收标准未全部达成或存在未解决 Known Gaps，不能标记 HG-3 通过。请先处理后再验收。"
        fi
        if verdict_is_self_inconsistent "$VERI_FILE"; then
            V_SEV=$(max_residual_severity "$VERI_FILE")
            emit_deny "⛔ 判决自相矛盾：verification.md 判决=PASS，但「残余风险」区含 ${V_SEV} 级风险。请修正判决或消除残余风险后再验收。"
        fi

        # ── 技术债登记校验（Phase 验收的最后一关）──
        # 为什么放在门禁层：「桩必须先登记」这条规则此前只存在于 AGENTS.md 的文本约束里，
        # 于是它和大多数纯文本规则一样会被跳过 —— 桩悄悄留在代码里，下一个 Phase 把它当真实现用。
        # 现在把它变成「不登记就过不了验收」。
        #
        # ⚠️ 只做**可被产物证实**的两件事，不去猜代码：
        #   1) 注册表存在（/feature 初始化时复制模板，缺失说明工作流初始化被跳过）
        #   2) 本 Phase 文档中声明的每个 @STUB(...) 标记都能在注册表里找到
        # 不做的事：不扫源码（成本高、误伤大）、不要求「本 Phase 必须新增条目」
        # （无债的 Phase 是正常的，强制新增会制造假条目）。
        DEBT_FILE="$SPEC_DIR/tech-debt-registry.md"
        if [ ! -f "$DEBT_FILE" ]; then
            emit_deny "⛔ 技术债注册表不存在：$(project_rel "$DEBT_FILE")。工作流初始化时应从 \`.specdev/tech-debt-registry-template.md\` 复制；请补建后再验收（注册表是所有 Phase 共用的唯一债务来源）。"
        fi

        # 从本 Phase 的文档里抽取 @STUB(标签) 标记并逐个核对
        # （只看 Phase 产物，不扫全仓源码：产物是 agent 自己声明的契约面）
        UNREGISTERED=""
        for _f in "$PHASE_DIR/implementation.md" "$PHASE_DIR/review.md" "$PHASE_DIR/verification.md"; do
            [ -f "$_f" ] || continue
            while IFS= read -r _tag; do
                [ -n "$_tag" ] || continue
                # 固定字符串匹配（非正则）：@STUB 标签可能含 / . : 等字符
                if ! grep -qF "$_tag" "$DEBT_FILE" 2>/dev/null; then
                    UNREGISTERED="$UNREGISTERED $_tag"
                fi
            done < <(grep -oE '@STUB\([^)]+\)' "$_f" 2>/dev/null | sort -u)
        done
        if [ -n "$UNREGISTERED" ]; then
            emit_deny "⛔ 存在未登记的技术债：本 Phase 声明了桩标记但注册表中查无对应条目 →${UNREGISTERED}。请先在 $(project_rel "$DEBT_FILE") 的「活跃债务」表中登记（ID / 源Phase / 文件:函数:行号 / 当前行为 / 预期行为 / 目标Phase / 阻塞），再标记 HG-3 通过。"
        fi
    fi

    # ── 检查是否试图设置 hg2=passed ──
    if printf '%s' "$NEW_CONTENT" | grep -qE '"hg2"[[:space:]]*:[[:space:]]*"passed"'; then
        check_file_valid "$SPEC_DIR/design.md" 10 "##" \
            || emit_deny "⛔ 流程不完整：尝试标记 HG-2 通过，但 design.md 不存在或内容无效。"
        check_file_valid "$SPEC_DIR/phase-plan.md" 10 \
            || emit_deny "⛔ 流程不完整：尝试标记 HG-2 通过，但 phase-plan.md 不存在或内容无效。"
        # 设计必须基于现状，而非凭空生成（L1–L5，见 check_design_evidence 注释）
        check_design_evidence "$SPEC_DIR/design.md" 1
    fi

    # ── 检查是否试图设置 hg1_5=passed（视觉基准确认，仅 UI 工作流）──
    if printf '%s' "$NEW_CONTENT" | grep -qE '"hg1_5"[[:space:]]*:[[:space:]]*"passed"'; then
        UI_ANY=$(read_any_phase_ui)
        case "$UI_ANY" in
            unknown)
                gate_unknown "无法从 phase-plan.md 的 DAG JSON 判定本工作流是否含 ui:true 的 Phase（文件缺失、无 JSON 块或解析失败）。hg1_5 的校验强度取决于此判定。"
                ;;
            true)
                check_file_valid "$SPEC_DIR/visual-baseline.md" 10 \
                    || emit_deny "⛔ 流程不完整：尝试标记 HG-1.5 通过，但 visual-baseline.md 不存在或内容无效。请先完成视觉基准生成（ui-ux-pro-max --design-system --persist）。"
                grep -q "冻结的 Design Tokens\|冻结值" "$SPEC_DIR/visual-baseline.md" 2>/dev/null \
                    || emit_deny "⛔ 视觉基准未冻结：visual-baseline.md 缺少「冻结的 Design Tokens」章节，无法作为比对基准。"
                if [ ! -d "$PROJECT_ROOT/design-system" ]; then
                    emit_deny "⛔ 设计系统未生成：design-system/ 目录不存在。请先执行 ui-ux-pro-max 的 --design-system --persist。"
                fi
                ;;
            *) ;;  # false：纯后端工作流，hg1_5 不适用
        esac
    fi

    # ── 检查是否试图设置 hg1=passed ──
    if printf '%s' "$NEW_CONTENT" | grep -qE '"hg1"[[:space:]]*:[[:space:]]*"passed"'; then
        check_file_valid "$SPEC_DIR/requirements.md" 10 "##" \
            || emit_deny "⛔ 流程不完整：尝试标记 HG-1 通过，但 requirements.md 不存在或内容无效。"
    fi

    # ── 检查是否在切换 current_phase（阶段跳跃）──
    if [ -n "$NEW_PHASE" ] && [ "$NEW_PHASE" != "$CURRENT_PHASE" ]; then
        if [ "$EFFECTIVE_HG3" != "passed" ]; then
            emit_deny "⛔ 阶段跳跃：current_phase 从 \`${CURRENT_PHASE:-<空>}\` 切换到 \`${NEW_PHASE}\`，但 hg3=${EFFECTIVE_HG3}（未通过）。完整流程：implementer → reviewer → verifier → HG-3 用户确认。"
        fi
    fi

    emit_allow
fi

# ============================================================
# 分支 B：Task —— 子 Agent 派发门禁
# ============================================================

# ── 解析子Agent ──
TOOL_INPUT_RAW=$(printf '%s' "$INPUT" | jq -r '.tool_input // "{}"' 2>/dev/null)
SUBAGENT=$(printf '%s' "$TOOL_INPUT_RAW" | jq -r '.subagent_type // empty' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(printf '%s' "$TOOL_INPUT_RAW" | jq -r '.subagent_name // empty' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(printf '%s' "$TOOL_INPUT_RAW" | grep -oE '(implementer|reviewer-correctness|reviewer-connectivity|reviewer-design|reviewer-visual|reviewer|verifier|plan-generator|requirement-analyst|code-explorer|wiki)' | head -1)

# 内置 agent 放行（非流程 agent，不受 Human Gate 约束）
case "$SUBAGENT" in
    explore|bash|browser|generalPurpose|shell) emit_allow ;;
esac

KNOWN="requirement-analyst|plan-generator|implementer|reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|reviewer-visual|verifier|code-explorer|wiki"
# ⚠️ 必须用 -E（POSIX ERE）。原 `grep -qP` 在 macOS BSD grep 上以退出码 2 失败，
#    而本行处于 `if ! ...` 中 → 失败被反向解读为「不在白名单」→ 提前放行全部子 Agent。
# ⚠️ 反向也必须 fail-closed：未知子 Agent 名（拼写错误 / 未登记）此前一律 allow，
#    等于用 `subagent_type: "implementr"` 即可绕过全部 Human Gate。现改为 deny。
if ! printf '%s' "$SUBAGENT" | grep -qxE "$KNOWN" 2>/dev/null; then
    gate_unknown "无法识别的子 Agent 名称：\`${SUBAGENT:-<空>}\`。流程 Agent 白名单：${KNOWN}"
fi

# ── 活跃工作流校验 ──
if [ "$WORKFLOW_ACTIVE" != "1" ]; then
    case "$SUBAGENT" in
        requirement-analyst|code-explorer) emit_allow ;;
        *) emit_deny "⛔ 无活跃工作流。请先使用 /feature 或 /bugfix 命令初始化。" ;;
    esac
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
if [ -z "$SLUG" ]; then
    gate_unknown "active-workflow 为空，无法确定工作流 slug。"
fi
SPEC_DIR="$PROJECT_ROOT/.specdev/specs/$SLUG"
STATUS_FILE="$SPEC_DIR/current-status.json"

if [ ! -f "$STATUS_FILE" ]; then
    case "$SUBAGENT" in
        requirement-analyst|code-explorer) emit_allow ;;
        *) emit_deny "⛔ 工作流状态文件缺失：$(project_rel "$STATUS_FILE")。请确保 /feature 或 /bugfix 命令已完成初始化。" ;;
    esac
fi

# ── 读取状态 ──
# ⚠️ v7 在读失败时降级为「全 pending / phase 空 / stage unknown」并继续。
#    虽然对 implementer 恰好表现为 deny，但那是巧合而非设计（hg3 路径已被绕过）。
#    现改为显式 deny：状态不可信 = 无法判定 = 不放行。
if ! read_status "$STATUS_FILE" 2>/dev/null; then
    gate_unknown "状态文件无法解析（JSON 损坏或缺失关键字段）：$(project_rel "$STATUS_FILE")"
fi

# ── 阶段一致性检查 ──
if [ "$CURRENT_STAGE" != "phase-implementation" ]; then
    case "$SUBAGENT" in
        implementer|reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|reviewer-visual|verifier)
            emit_deny "⛔ 阶段不一致：当前处于 \`${CURRENT_STAGE}\` 阶段，但尝试调度实施类 Agent（${SUBAGENT}）。请先完成需求确认（HG-1）与方案确认（HG-2）。"
            ;;
    esac
fi

# ── 按 Agent 类型校验 ──
case "$SUBAGENT" in
    requirement-analyst)
        emit_allow
        ;;

    plan-generator)
        if [ "$HG1" != "passed" ]; then
            emit_deny "⛔ Human Gate 1 未通过。请先确认需求文档后再进入设计阶段。"
        fi
        check_file_valid "$SPEC_DIR/requirements.md" 10 "##" \
            || emit_deny "⛔ 前置条件不满足：requirements.md 不存在或内容无效（少于 10 行或缺少结构化章节）。"
        emit_allow
        ;;

    implementer)
        if [ "$HG2" != "passed" ]; then
            emit_deny "⛔ Human Gate 2 未通过。请先确认设计方案后再开始实施。"
        fi
        if [ "$LOOP_COUNT" -ge 2 ]; then
            emit_deny "⛔ 实施循环已达上限（loop_count=${LOOP_COUNT} >= 2）。请用户介入决定下一步。"
        fi
        validate_phase_id

        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        if [ ! -f "$PHASE_DIR/spec.md" ]; then
            emit_deny "⛔ Phase spec 不存在：$(project_rel "$PHASE_DIR/spec.md")。请确保 plan-generator 已创建 phases/<phase>/spec.md。"
        fi
        # 阶段跳跃检测：必须有 repo-exploration.md（code-explorer 已完成）
        check_file_valid "$PHASE_DIR/repo-exploration.md" 10 \
            || emit_deny "⛔ 阶段跳跃：repo-exploration.md 不存在或内容不足。请先委托 code-explorer 进行代码调研。"

        # UI Phase 前置：界面契约与冻结基准缺一不可
        PHASE_UI=$(read_phase_ui)
        case "$PHASE_UI" in
            unknown)
                gate_unknown "无法判定当前 Phase（${CURRENT_PHASE}）的 ui 标记：phase-plan.md 的 DAG JSON 缺失该字段或解析失败。UI 门禁强度取决于此判定。"
                ;;
            true)
                check_file_valid "$SPEC_DIR/ui-spec.md" 10 \
                    || emit_deny "⛔ UI Phase 缺少界面契约：本 Phase 标记为 ui: true，但 ui-spec.md 不存在或内容无效。implementer 无布局骨架与状态矩阵可依，请先回到需求阶段补齐。"
                check_file_valid "$SPEC_DIR/visual-baseline.md" 10 \
                    || emit_deny "⛔ UI Phase 缺少视觉基准：本 Phase 标记为 ui: true，但 visual-baseline.md 不存在或内容无效。implementer 将退回「即兴发挥样式」，请先回到设计阶段生成并冻结基准。"
                ;;
            *) ;;
        esac

        # Git 分支校验
        # ⚠️ v7 在 git 不可用（返回 unknown）时跳过校验 → 分支隔离形同虚设。
        EXPECTED_BRANCH="impl-${CURRENT_PHASE}"
        ACTUAL_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || printf '%s' "")
        if [ -z "$ACTUAL_BRANCH" ]; then
            gate_unknown "无法读取当前 git 分支（git 不可用或不在仓库内）。无法确认 Phase 隔离。"
        fi
        if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
            emit_deny "⛔ Git 分支不匹配：当前 \`${ACTUAL_BRANCH}\`，需要 \`${EXPECTED_BRANCH}\`。请先创建/切换分支。"
        fi
        emit_allow
        ;;

    reviewer|reviewer-correctness|reviewer-design|reviewer-connectivity|reviewer-visual)
        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        check_file_valid "$PHASE_DIR/implementation.md" 10 "##" \
            || emit_deny "⛔ 阶段跳跃：implementation.md 不存在或内容无效。请先完成 implementer 实施。"
        validate_phase_id

        # UI Phase 原型门禁：用户未确认原型前不得进入审查
        PHASE_UI=$(require_ui_gates)

        # reviewer-visual 专属前置：UI Phase 必须有冻结的视觉基准
        if [ "$SUBAGENT" = "reviewer-visual" ] && [ "$PHASE_UI" = "true" ]; then
            check_file_valid "$SPEC_DIR/visual-baseline.md" 10 \
                || emit_deny "⛔ 视觉基准缺失：本 Phase 标记为 ui: true，但 visual-baseline.md 不存在或内容不足。reviewer-visual 无基准可对照，请先回到 plan-generator 生成并冻结视觉基准。"
        fi
        emit_allow
        ;;

    verifier)
        PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"
        check_file_valid "$PHASE_DIR/review.md" 5 "判决" \
            || emit_deny "⛔ 阶段跳跃：review.md 不存在或缺少「判决」字段。请先完成 reviewer 审查合并。"

        VERDICT=$(parse_review_verdict "$PHASE_DIR/review.md" || printf '%s' "")
        if [ -z "$VERDICT" ]; then
            emit_deny "⛔ review.md 判决行无法解析：必须是单值判决行「## 判决：PASS」（或 MUST-FIX / SHOULD-FIX），不得加粗、不得追加说明、不得保留多值枚举。"
        fi
        if [ "$VERDICT" = "MUST-FIX" ]; then
            emit_deny "⛔ 审查判决为 MUST-FIX。请先委托 implementer 修复后重新审查，再进行验证。"
        fi
        validate_phase_id

        # UI Phase 原型门禁：用户未确认原型前不得进入验证
        PHASE_UI=$(require_ui_gates)

        # UI Phase 视觉验证前置：无基准则无法执行视觉比对
        if [ "$PHASE_UI" = "true" ]; then
            check_file_valid "$SPEC_DIR/visual-baseline.md" 10 \
                || emit_deny "⛔ 视觉基准缺失：本 Phase 标记为 ui: true，但 visual-baseline.md 不存在。verifier 无法执行视觉比对（基准对比表无 ground truth），请先补齐基准。"
        fi
        emit_allow
        ;;

    code-explorer)
        # ── 双模式分流（v8.4 新增）──
        # code-explorer 有 4 个文档场景，其中 3 个发生在「尚未拆分 Phase」时：
        #   /research 独立调研、/plan 架构设计前、/bugfix 根因分析前
        # 此前对它们一律套 validate_phase_id → 因 current_phase 为空而 deny，
        # 即「设计前调研」这条能力被门禁自己关闭了。实测：在任一工作流内部
        # 派发 code-explorer 一律 deny，唯一可达路径是「状态文件根本不存在」
        # （那是 bootstrap 分支的副作用，不是设计）。
        if [ -n "$CURRENT_PHASE" ]; then
            # Phase 级模式：输出到 phases/<phase>/，Phase ID 必须 ∈ DAG JSON
            validate_phase_id
        else
            case "$CURRENT_STAGE" in
                requirement-analysis|architecture-design)
                    # 工作流级模式：无 Phase 可校验。code-explorer 是只读 agent，
                    # 且实施类 agent 的阶段检查独立生效（见上方阶段一致性检查），
                    # 因此放行它不构成「绕过 HG-2 进入实施」的通道。
                    ;;
                *)
                    # fail-closed：current_phase 为空却已进入实施阶段 = 状态损坏。
                    # hg3 写入同样依赖 current_phase 定位产物目录，此处放行会掩盖损坏。
                    emit_deny "⛔ 状态不一致：current_phase 为空，但 current_stage=\`${CURRENT_STAGE}\`。实施阶段的 Phase 为空说明 $(project_rel "$STATUS_FILE") 已损坏（HG-3 写入也依赖该字段定位 Phase 产物）。请先修复状态文件。"
                    ;;
            esac
        fi
        emit_allow
        ;;

    wiki)
        emit_allow
        ;;

    *)
        gate_unknown "子 Agent \`${SUBAGENT:-<空>}\` 未匹配任何校验分支。"
        ;;
esac

exit 0
