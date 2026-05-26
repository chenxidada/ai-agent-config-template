# Review Report Template

> **Append mode**: see `unified-pipeline.md` §"Loop Document Append Mode".

## Scope Reviewed

## Alignment With Approved Plan

## Logic Correctness Check

<!-- For each acceptance criterion in the sub-spec, verify whether the code correctly implements it -->

| # | Acceptance Criterion | Code Location | Correctly Implemented? | Notes |
|---|---------------------|---------------|----------------------|-------|

## Test Coverage Assessment

<!-- Which Validation Plan scenarios are covered by implementer's tests? Which are missing? -->

| # | Scenario (from Validation Plan) | Test Exists? | Test File:Line | Gap Notes |
|---|--------------------------------|-------------|----------------|-----------|

## Must-Fix Findings

## Should-Fix Findings

## Optional Improvements

## Hidden Risks / Edge Cases

## Stubs Identified（检测到的桩代码）

<!--
  判定：
  🔴 BLOCKER → 未标注的桩，must-fix（实现或补注册）
  ⚠️ 已知桩 → implementer 已标注，确认延期目标正确
  🟡 条件桩 → 有条件编译，标注可用/不可用场景
-->

| # | 判定 | 文件:函数:行号 | 当前行为 | 已注册？ | 动作 |
|---|:---:|---------------|---------|:---:|------|
| — | — | — | — | — | — |

### 处理说明
- 已注册于 tech-debt-registry.md 的桩 → ⚠️ 确认分类正确
- 未注册的桩 → 🔴 must-fix：要求 implementer 补注册或补实现
- 已解决的历史桩 → 确认后在 tech-debt-registry.md 移到 §已解决

## Additional Test Scenarios

<!-- New scenarios discovered during review that are NOT in the original Validation Plan -->
<!-- The validator should execute these in addition to the original Validation Plan -->

| # | Scenario | Why Added | Input / Precondition | Expected Behavior | Verification Method |
|---|----------|-----------|----------------------|-------------------|---------------------|

## Recommended Validation Commands

<!-- Specific commands the validator should run to verify the implementation -->
<!-- Include: build commands, test commands, manual verification steps -->
<!-- For frontend changes: include visual validation commands (start dev server, run screenshot script) -->

```bash
# Example:
# npm run build
# npm test -- --grep "feature-name"
# curl -X POST localhost:3000/api/endpoint -d '{"test": "data"}'

# Frontend visual validation example:
# npm run dev &
# npx playwright install chromium  (if not installed)
# node specs/phases/.../test-scripts/visual-validation.mjs
```

## Review Verdict

- Ready for validation / Needs fixes first
