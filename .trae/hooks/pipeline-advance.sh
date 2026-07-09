#!/bin/bash
# ============================================
# pipeline-advance.sh — Agent 完成后引导 (Trae 版)
# 绑定: Stop
# schema: .specdev/specs/{slug}/current-status.json
# 协议: stdin JSON → stdout 文本(注入给Agent作为下一步指引)
#
# 关键适配：Trae Stop 事件 stdin 只有通用字段：
#   { session_id, cwd, hook_event_name, workspace_roots }
# 没有 agent_name / exit_code 等。
# 因此改为从 current-status.json 的阶段状态推断当前进度。
#
# 原则: HG 状态只能由用户在对话中显式确认后由 Agent 更新
# ============================================

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)

# 切到工作目录
cd "$CWD" 2>/dev/null || true

# ── 更新心跳时间戳（Stop 事件不算超时） ──
date +%s > /tmp/.trae-pipeline-heartbeat 2>/dev/null || true

# 读取活跃工作流
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    # 无活跃工作流，静默退出
    exit 0
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
STATUS_FILE=".specdev/specs/$SLUG/current-status.json"

if [ ! -f "$STATUS_FILE" ]; then
    exit 0
fi

# 读取状态
CURRENT_STAGE=$(jq -r '.current_stage // "unknown"' "$STATUS_FILE")
CURRENT_PHASE=$(jq -r '.current_phase // ""' "$STATUS_FILE")
HG1=$(jq -r '.human_gates.hg1 // "pending"' "$STATUS_FILE")
HG2=$(jq -r '.human_gates.hg2 // "pending"' "$STATUS_FILE")
HG3=$(jq -r '.human_gates.hg3 // "pending"' "$STATUS_FILE")
SPEC_DIR=".specdev/specs/$SLUG"

# ── 基于状态推断当前阶段并给出引导 ──

# 阶段 1：需求分析刚完成（有 requirements.md 但 HG-1 未过）
if [ "$CURRENT_STAGE" = "requirement-analysis" ] && [ "$HG1" = "pending" ]; then
    if [ -f "$SPEC_DIR/requirements.md" ]; then
        cat <<'MSG'
📋 **requirement-analyst 已完成**

输出文件：`.specdev/specs/<workflow>/requirements.md`

## ⏸️ Human Gate 1 — 需求确认

请将需求文档呈现给用户进行确认，等待用户明确回复（例如「确认」「OK」「继续」）后，手动更新:
- `current-status.json`: `"hg1": "passed"`

## 📚 KB Sync (非阻塞)
HG-1 通过后（异步，不等待）：
- resolve_folder_path: "Projects/<project>/Topics/" → folderId
- MCP 可用：save_document(title: "[topic:<slug>] 需求文档", content: requirements.md 全文, folderId)
- MCP 不可用：写入 kb-pending/topic-<slug>.json

**不要自动继续。不要替用户做决定。**
MSG
    fi
    exit 0
fi

# 阶段 2：架构设计刚完成（有 design.md 但 HG-2 未过）
if [ "$CURRENT_STAGE" = "architecture-design" ] && [ "$HG2" = "pending" ]; then
    if [ -f "$SPEC_DIR/design.md" ] && [ -f "$SPEC_DIR/phase-plan.md" ]; then
        cat <<'MSG'
🏗️ **plan-generator 已完成**

输出文件：`.specdev/specs/<workflow>/design.md` + `phase-plan.md` + `phases/<phase>/spec.md`

## ⏸️ Human Gate 2 — 设计方案确认

请将设计方案呈现给用户进行确认，等待用户明确回复（例如「确认」「开始实施」）后，手动更新:
- `current-status.json`: `"hg2": "passed"`

## 📚 KB Sync (非阻塞)
HG-2 通过后（异步，不等待）：
- resolve_folder_path: "Projects/<project>/Decisions/" → folderId
- MCP 可用：save_document(title: "[decision:<slug>] 架构设计", content: design.md 全文, folderId)
- MCP 不可用：写入 kb-pending/decision-<slug>.json

**不要自动继续。不要替用户做决定。**
MSG
    fi
    exit 0
fi

# 阶段 3：Phase 实施中
if [ "$CURRENT_STAGE" = "phase-implementation" ] && [ -n "$CURRENT_PHASE" ]; then
    PHASE_DIR="$SPEC_DIR/phases/$CURRENT_PHASE"

    # 读取当前 Phase 各步骤状态
    IMPL_STATUS=$(jq -r ".phases[\"$CURRENT_PHASE\"].implementer // \"pending\"" "$STATUS_FILE" 2>/dev/null)
    REV_STATUS=$(jq -r ".phases[\"$CURRENT_PHASE\"].reviewer // \"pending\"" "$STATUS_FILE" 2>/dev/null)
    VER_STATUS=$(jq -r ".phases[\"$CURRENT_PHASE\"].verifier // \"pending\"" "$STATUS_FILE" 2>/dev/null)

    # 情况 A：implementer 刚完成（有 implementation.md 但 reviewer 还是 pending）
    if [ -f "$PHASE_DIR/implementation.md" ] && [ "$REV_STATUS" = "pending" ]; then
        cat <<'MSG'
💻 **implementer 已完成**

输出文件：`.specdev/specs/<workflow>/phases/<phase>/implementation.md`

下一步：
- **并行**委托 3 个 reviewer（同时执行）：
  - `reviewer-correctness` — 实现正确性
  - `reviewer-design` — 设计一致性
  - `reviewer-connectivity` — 集成连通性
- 等 3 个全部完成后，读取各自报告合并为 `review.md`

如果合并后判决 MUST-FIX：
- 委托 implementer 修复，loop_count +1（由 pipeline-gate.sh 检查上限 2）
MSG
        exit 0
    fi

    # 情况 B：reviewer 完成（检查 3 份报告是否全部存在）
    RC="$PHASE_DIR/review-correctness.md"
    RD="$PHASE_DIR/review-design.md"
    RN="$PHASE_DIR/review-connectivity.md"
    REVIEW_MERGED="$PHASE_DIR/review.md"

    # 部分 reviewer 完成（有至少一份但不全）
    RC_EXIST=0; RD_EXIST=0; RN_EXIST=0
    [ -f "$RC" ] && RC_EXIST=1
    [ -f "$RD" ] && RD_EXIST=1
    [ -f "$RN" ] && RN_EXIST=1
    TOTAL=$((RC_EXIST + RD_EXIST + RN_EXIST))

    if [ "$TOTAL" -gt 0 ] && [ "$TOTAL" -lt 3 ] && [ ! -f "$REVIEW_MERGED" ]; then
        DONE_LIST=""
        [ "$RC_EXIST" = 1 ] && DONE_LIST="${DONE_LIST}reviewer-correctness ✅ "
        [ "$RD_EXIST" = 1 ] && DONE_LIST="${DONE_LIST}reviewer-design ✅ "
        [ "$RN_EXIST" = 1 ] && DONE_LIST="${DONE_LIST}reviewer-connectivity ✅ "
        echo "🔍 并行审查进度：${DONE_LIST}（${TOTAL}/3 完成）。等待全部完成后 merge 判决。"
        exit 0
    fi

    # 3 份报告全部就绪但尚未 merge
    if [ "$TOTAL" -eq 3 ] && [ ! -f "$REVIEW_MERGED" ]; then
        cat <<'MSG'
🔍 **3 个并行 reviewer 全部完成**

请读取 3 份报告并 merge 判决：
- `review-correctness.md`
- `review-design.md`
- `review-connectivity.md`

合并规则：任一 MUST-FIX → 整体 MUST-FIX。
写入合并后的 `review.md`，然后：
- 判决 = **PASS** 或 **SHOULD-FIX**：委托 **verifier** 进行验证
- 判决 = **MUST-FIX**：委托 **implementer** 修复（loop_count +1）→ 重新 reviewer
MSG
        exit 0
    fi

    # 情况 C：/brief 单视角 reviewer 完成
    if [ -f "$REVIEW_MERGED" ] && [ "$VER_STATUS" = "pending" ] && [ ! -f "$PHASE_DIR/verification.md" ]; then
        cat <<'MSG'
🔍 **reviewer 已完成**

输出文件：`.specdev/specs/<workflow>/phases/<phase>/review.md`

请检查审查判决：
- 判决 = **PASS** 或 **SHOULD-FIX**：委托 **verifier** 进行验证
- 判决 = **MUST-FIX**：委托 **implementer** 修复（loop_count +1）→ reviewer
MSG
        exit 0
    fi

    # 情况 D：verifier 完成（有 verification.md 但 HG-3 未过）
    if [ -f "$PHASE_DIR/verification.md" ] && [ "$HG3" = "pending" ]; then
        cat <<'MSG'
✅ **verifier 已完成**

输出文件：`.specdev/specs/<workflow>/phases/<phase>/verification.md`

## ⏸️ Human Gate 3 — Phase 验收

请将验证报告呈现给用户。

**先展示改动清单**：运行 `git diff --stat` + `git status -s`，让用户知道哪些文件将被提交。

等待用户回复：
- 用户说"不通过"/"需要修改" → 停止，了解修改内容
- 用户说"通过"/"验收通过"/"确认" → **一次性执行全部**：
  - touch /tmp/git-commit-allowed && git add -A && git commit -m "impl-<phase-id>: <概要>"
  - git checkout main && git merge impl-<phase-id> && git branch -d impl-<phase-id>
  - 更新 `current-status.json`: `"hg3": "passed"`, `"loop_count": 0`
  - 如有下一 Phase：更新 `"current_phase": "phase-N-xxx"` 并创建新分支

⚠️ 禁止盲 `git add -A`：必须先用 `git diff --stat` + `git status -s` 展示改动清单。

## 📚 Knowledge Base Sync (非阻塞)

Phase 验收后，异步同步该 Phase 全套 spec 文档到知识库：
- resolve_folder_path: "Projects/<project>/Phases/<current_phase>/" → folderId
- MCP 可用时依次 save_document（不阻塞）：
  1. spec.md (title: "[spec] <phase-id> - Phase 规格")
  2. repo-exploration.md (title: "[exploration] <phase-id> - 代码调研")
  3. implementation.md (title: "[impl] <phase-id> - 实现摘要")
  4. review.md (title: "[review] <phase-id> - 审查报告")
  5. verification.md (title: "[verify] <phase-id> - 验证报告")
- MCP 不可用：写入 kb-pending/phase-<phase-id>-<n>.json 降级

⚠️ **同步是异步的，不影响 pipeline 推进。**

**不要自动继续。不要替用户做决定。**
MSG
        exit 0
    fi

    # 情况 E：code-explorer 完成（有 repo-exploration.md 但无 implementation.md）
    if [ -f "$PHASE_DIR/repo-exploration.md" ] && [ ! -f "$PHASE_DIR/implementation.md" ]; then
        cat <<'MSG'
🔎 **code-explorer 已完成**

输出文件：`.specdev/specs/<workflow>/phases/<phase>/repo-exploration.md`

下一步：
1. 创建 git 分支（如果还没有）：`git checkout -b impl-<phase-id>`
2. 委托 **implementer** 开始实施（implementer 会自动读取 repo-exploration.md）
MSG
        exit 0
    fi
fi

# 默认：无法推断阶段，给出通用提示
cat <<MSG
✅ Agent 已停止。当前工作流: $SLUG, 阶段: $CURRENT_STAGE, Phase: ${CURRENT_PHASE:-无}
HG-1=$HG1, HG-2=$HG2, HG-3=$HG3

请根据 current-status.json 确定下一步操作。
MSG

exit 0
