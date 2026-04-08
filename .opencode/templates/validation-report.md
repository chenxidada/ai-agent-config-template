# Validation Report Template

## Scope Validated

## Test Execution Matrix

<!-- Merge all test scenarios from: sub-spec Validation Plan + reviewer Additional Test Scenarios + validator's own findings -->

| # | Scenario | Source | Method | Command / Test | Result | Evidence |
|---|----------|--------|--------|----------------|--------|----------|
<!-- Source: sub-spec VP#N | reviewer #N | validator #N -->
<!-- Method: existing-test | new-script | manual-cmd | build-check | visual-screenshot -->
<!-- Result: PASS | FAIL | SKIP (with reason) -->
<!-- Example:
| 1 | Normal user login | sub-spec VP#1 | existing-test | npm test -- auth.test.ts | PASS | all 3 assertions pass |
| 2 | Empty password | sub-spec VP#2 | new-script | node test-scripts/test-empty-pwd.js | PASS | returns 400 as expected |
| 3 | Invalid token | reviewer #1 | manual-cmd | curl -H "Auth: bad" localhost:3000/api | PASS | 401 response |
| 4 | Page renders correctly | sub-spec VP#3 | visual-screenshot | node test-scripts/visual-validation.mjs | PASS | screenshot: screenshots/01-initial-load.png |
| 5 | Mobile responsive layout | reviewer #2 | visual-screenshot | node test-scripts/visual-validation.mjs | PASS | screenshot: screenshots/06-mobile-375px.png |
-->

## Acceptance Criteria Verdict

<!-- Map each acceptance criterion from the sub-spec to test results -->

| # | Criterion | Verified By (Scenario #) | Status | Notes |
|---|-----------|-------------------------|--------|-------|

## Build & Lint Check

- [ ] Build passes: <!-- command and result -->
- [ ] Lint passes: <!-- command and result -->

## Verification Scripts Created

<!-- List any temporary test scripts created during validation -->

| Script | Purpose | Location |
|--------|---------|----------|

## Visual Validation Screenshots

<!-- Only populated when the implementation involves frontend / UI changes -->
<!-- All screenshots saved to specs/phases/<phase-id>/slices/<sub-spec-id>/screenshots/ -->

| # | Screenshot | Page / State | What It Verifies | Result |
|---|-----------|-------------|-----------------|--------|
<!-- Example:
| 1 | screenshots/01-initial-load.png | /dashboard after login | Page renders with correct layout and data | PASS |
| 2 | screenshots/02-form-error.png | /settings with invalid input | Error message displayed correctly | PASS |
| 3 | screenshots/03-mobile-375px.png | /dashboard at 375px viewport | Responsive layout, no horizontal scroll | PASS |
-->

## Boundary / Regression Checks

## Result

- Pass / Partial / Fail
- Scenarios: X total, Y passed, Z failed, W skipped

## Findings

## Unverified Items

<!-- Items that could not be tested in the current environment, with reason -->

## Risks / Regressions

## Follow-Up Work
