# Review Report Template

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
