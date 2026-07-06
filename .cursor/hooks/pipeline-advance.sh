#!/bin/bash
# ============================================
# pipeline-advance.sh — 子Agent 完成后引导 v4
# 绑定: subagentStop
# schema: .specdev/specs/{slug}/current-status.json
# 原则: HG 状态只能由用户在对话中显式确认后由 Agent 更新
# ============================================

INPUT=$(cat 2>/dev/null || echo '{}')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "subagent"')
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "subagent"')

# 读取活跃工作流
ACTIVE_FILE=".specdev/active-workflow"
if [ ! -f "$ACTIVE_FILE" ]; then
    echo "⚠️  子Agent 已完成，但无活跃工作流。请使用 /feature 或 /bugfix 初始化。"
    exit 0
fi

SLUG=$(head -1 "$ACTIVE_FILE" | tr -d '[:space:]')
STATUS_FILE=".specdev/specs/$SLUG/current-status.json"

if [ "$EXIT_CODE" != "0" ]; then
    cat <<MSG
❌ **$AGENT_NAME** 异常退出 (exit code: $EXIT_CODE)
请检查子Agent 输出，确认问题后重试。
MSG
    exit 0
fi

AGENT_LOWER=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]')

if echo "$AGENT_LOWER" | grep -q "requirement-analyst"; then
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

elif echo "$AGENT_LOWER" | grep -q "plan-generator"; then
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

elif echo "$AGENT_LOWER" | grep -q "implementer"; then
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

elif echo "$AGENT_LOWER" | grep -q "reviewer-correctness"; then
    echo "🔍 **reviewer-correctness**（1/3 并行审查）已完成。等待 reviewer-design + reviewer-connectivity。"

elif echo "$AGENT_LOWER" | grep -q "reviewer-design"; then
    echo "🔍 **reviewer-design**（并行审查中）已完成。检查是否 3 份报告全部就绪，准备 merge。"

elif echo "$AGENT_LOWER" | grep -q "reviewer-connectivity"; then
    echo "🔍 **reviewer-connectivity**（并行审查中）已完成。检查是否 3 份报告全部就绪，准备 merge。"

elif echo "$AGENT_LOWER" | grep -q "reviewer"; then
    cat <<'MSG'
🔍 **reviewer 已完成**

输出文件：`.specdev/specs/<workflow>/phases/<phase>/review.md`

请检查审查判决：
- 判决 = **PASS** 或 **SHOULD-FIX**：委托 **verifier** 进行验证
- 判决 = **MUST-FIX**：委托 **implementer** 修复（loop_count +1）→ reviewer
MSG

elif echo "$AGENT_LOWER" | grep -q "verifier"; then
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
  1. spec.md, repo-exploration.md, implementation.md, review.md, verification.md
- MCP 不可用：写入 kb-pending/ 降级

⚠️ **同步是异步的，不影响 pipeline 推进。**


**不要自动继续。不要替用户做决定。**
MSG

elif echo "$AGENT_LOWER" | grep -q "code-explorer"; then
    echo "🔎 **code-explorer** 已完成。现在可以继续工作流的下一步。"
else
    echo "✅ **$AGENT_NAME** 已完成。"
fi

exit 0
