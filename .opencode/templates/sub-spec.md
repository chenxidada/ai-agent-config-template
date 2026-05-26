# Sub-Spec Template

## Goal

## Why This Sub-Spec Now

## Scope

## Out Of Scope

## Related Modules

## Design / Contract Notes

## Expected File Outputs

## Validation Plan

### Test Scenarios

<!-- solution-architect designs these based on acceptance criteria -->
<!-- reviewer may add more scenarios during review -->

| # | Scenario | Input / Precondition | Expected Output / Behavior | Type |
|---|----------|----------------------|---------------------------|------|
<!-- Type: functional | boundary | error-handling | regression | performance | visual -->
<!-- Use "visual" type for frontend scenarios that require screenshot-based verification -->
<!-- Example:
| 1 | Normal user login | valid credentials | redirect to dashboard, session created | functional |
| 2 | Empty password | username filled, password empty | show validation error, no API call | boundary |
| 3 | Invalid token format | malformed JWT | return 401, log warning | error-handling |
| 4 | Dashboard renders correctly | logged-in user | page shows user name, nav bar, data table | visual |
| 5 | Mobile responsive layout | viewport 375px | no horizontal scroll, hamburger menu visible | visual |
-->

### Regression Checks

<!-- List existing features that must continue working after this change -->

- [ ] ...

### Build & Lint

- [ ] Build passes without errors
- [ ] No new lint warnings introduced

## Completion Criteria

## Change Notes

- Why changed:
- What changed:
- Impact:

## Amendments

<!-- 
  Amendments记录实现过程中经reviewer批准的偏差。
  由reviewer在批准implementer偏差后填写。
  每个amendment标注：原计划章节、修改后方案、批准日期、审核人、偏差来源。
-->

| # | 日期 | 原计划章节 | 修改为 | 批准人 | 偏差来源 |
|---|------|-----------|--------|--------|---------|
| — | — | — | — | — | — |

### 如何填写Amendments

1. **implementer** 在 `implementation-summary.md` 的 Deviations 章节中记录偏差，标注影响的 sub-spec 章节编号
2. **reviewer** 审查偏差：如批准，在本表增加一行，填写：
   - 序号（A1, A2...）
   - 日期
   - 原计划内容（引用 sub-spec.md 的章节号）
   - 修改后方案（简要描述）
   - 批准人（reviewer）
   - 偏差来源（implementation-summary.md 的 Deviations 章节）
