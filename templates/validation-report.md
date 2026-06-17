# Validation Report

**Sub-Spec**: `<sub-spec-id>`
**Phase**: `<phase-id>`
**Date**: `<YYYY-MM-DD>`

## 1. Overview

- **Verdict**: pass / partial / fail
- **Validator**: automated
- **Validation scope**: what was tested and what was explicitly excluded

## 2. Test Execution Matrix

| Scenario ID | Source | Description | Result | Evidence |
|------------|--------|-------------|:------:|----------|
| | | | | |

**Legend**: ✅ Pass / ⚠️ Partial / ❌ Fail / ⬚ Skipped

## 3. End-to-End Behavioral Verification

| Path Tested | Method | Expected | Actual | Verdict |
|------------|--------|----------|--------|:------:|
| | | | | |

## 4. Build & Test Results

| Command | Result | Notes |
|---------|:------:|-------|
| | | |

## 5. Acceptance Criteria Assessment

| Criterion ID | Description | Status | Evidence |
|-------------|-------------|:------:|----------|
| | | | |

## 6. Findings

### 6.1 Critical Findings (🔴)
_Issues that affect correctness, security, or primary behavior._

### 6.2 Medium Findings (🟡)
_Edge cases, secondary features, or partial coverage._

### 6.3 Low Findings (🟢)
_Cosmetic, logging, or non-functional gaps._

## 7. Stub / Placeholder Check

| Function | Registered in Tech Debt? | Parameter Variation Test | Verdict |
|----------|:------------------------:|--------------------------|:------:|
| | | | |

## 8. Pipeline Compliance

### Stage Execution Check
| Pipeline Stage | Dispatched? | Output File Exists? | Notes |
|---------------|:-----------:|:-------------------:|-------|
| repo-explorer | ✅ / ❌ | ✅ / ❌ | |
| requirement-analyst | ✅ / ❌ | ✅ / ❌ | |
| solution-architect | ✅ / ❌ | ✅ / ❌ | |
| implementer | ✅ / ❌ | ✅ / ❌ | |
| reviewer | ✅ / ❌ | ✅ / ❌ | |
| validator | ✅ / ❌ | ✅ / ❌ | |

### Branch Integrity Check
| File Modified | Branch | Agent | Compliance |
|--------------|--------|-------|-----------|
| `<file>` | `<branch>` | `<agent>` | ✅ / ❌ |

### Compliance Verdict
- ✅ COMPLIANT: All changes on impl-* branches, all stages dispatched
- ⚠️ PARTIAL: <N> files modified outside impl-* branches (see findings)
- 🔴 NON-COMPLIANT: Pipeline stages skipped or bypassed

## 9. Residual Risk Assessment

| Risk | Severity | Mitigation |
|------|:--------:|------------|
| | | |

## 10. Verification Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| | | |

## 11. Post-Validation Notes

Issues that need follow-up in future phases or sub-specs.
