<!-- Phase Exit Deliverable: "what was promised vs what was delivered" -->

# Phase {X} Scope Gap Report

> **Phase**: {phase-id}
> **Generated**: {ISO date}
> **SS Count**: {N completed} / {N planned}

## 一、CapabilityClaim 完成度

| # | Claim ID | Description | Status | Verify Environment | Notes |
|---|----------|-------------|:------:|-------------------|-------|
| 1 | CC-1 | {description} | ✅ Complete | {env met} | |
| 2 | CC-2 | {description} | ⚠️ Partial | {env not met} | {why partial} |
| 3 | CC-3 | {description} | ❌ Deferred | N/A | Deferred to Phase Y |

**Summary**: {N}/{Total} complete, {N} partial, {N} deferred

## 二、推迟/未完成项分类

| # | Item | Type | Target Phase | Blocks Downstream? | Related AC |
|---|------|:----:|:------------:|:------------------:|-----------|
| 1 | {item} | Deferred | Phase Y | Yes (AC-XX depends) | AC-XX |
| 2 | {item} | Degraded | Needs HW | No | — |
| 3 | {item} | Missed | TBD | TBD | — |

Type definitions:
- **Deferred**: Intentional scope control, planned for a specific future Phase
- **Degraded**: Environment/hardware limitation, needs external enablement
- **Missed**: Unintentional gap discovered during review/analysis

## 三、Should-Fix 汇总

| # | Source | Issue | Severity | Fix Timeline | Status |
|---|--------|-------|:--------:|:------------:|:------:|
| 1 | SS-{N} review S-{M} | {description} | should-fix | Phase {Y} SS-{Z} | pending |

**Total**: {N} should-fix items, {N} resolved in-phase, {N} carried forward

## 四、Design Document Update Checklist

| # | Design Doc Section | Update Content | Status |
|---|-------------------|---------------|:------:|
| 1 | §{X.Y} {section name} | {what changed} | ✅ Done |
| 2 | §{X.Y} {section name} | {what needs updating} | ❌ Pending |

## 五、Phase Exit Verdict

- [ ] All planned SS impl-reports submitted
- [ ] All planned SS review-reports submitted  
- [ ] CapabilityClaims all verified or explicitly marked partial/deferred
- [ ] Deferred items registered with target Phase
- [ ] Should-fix items tracked with fix timeline
- [ ] Design document updates executed or tracked
- [ ] No "Missed" items with unknown impact

**Exit Decision**: {PASS / PASS_WITH_CONDITIONS / BLOCK}

Conditions (if PASS_WITH_CONDITIONS):
- {condition 1}
- {condition 2}
