# requirements-to-implementation-workflow

Use this as the master controller workflow from product idea or requirement document to validated implementation.

## Stage Order

1. `repo-explorer`
   - map the relevant repository areas before planning or design
   - use `templates/repo-exploration-output.md`

2. `requirement-analyst`
   - clarify scope, MVP, functional areas, and requirement structure with enough quality to anchor the project `master-spec`
   - use `templates/requirements-output.md`

3. `knowledge-manager`
   - auto-trigger checkpoint sync for the completed requirement stage
   - save the clarified requirement as a `Topic Doc` or `Decision Doc`

4. `program-planner`
   - produce the project `master-spec`
   - define top-level modules, phases, dependencies, and the recommended starting phase
   - use `templates/master-spec.md`

5. `task-planner`
   - produce the current `phase-spec`
   - break the phase into ordered `sub-spec` candidates
   - use `templates/phase-spec.md` and `templates/task-plan-output.md`

6. `solution-architect`
   - refine the current approved `sub-spec`
   - define technical design for that `sub-spec`
   - use `templates/sub-spec.md` and `templates/solution-design-output.md`

7. Human confirmation gate
   - stop for user review after `master-spec`, `phase-spec`, and current `sub-spec` are ready
   - do not enter implementation until the current `sub-spec` is explicitly confirmed

8. `knowledge-manager`
    - auto-trigger checkpoint sync for completed planning and architecture work
    - sync plan and architecture milestones as `Decision Doc` and supporting `Topic Doc` entries when needed

9. `implementer`
   - implement only the approved current `sub-spec`
    - use `templates/implementation-summary.md`

10. `reviewer`
    - review the implementation for scope drift, maintainability, and hidden risk
    - use `templates/review-report.md`

11. `validator`
    - validate against acceptance criteria
    - use `templates/validation-report.md`

12. `knowledge-manager`
     - auto-trigger checkpoint sync for completed implementation and validation work
     - sync implementation and validation outcome
     - update the task record and `current-status`

13. Human continuation gate
   - report current `sub-spec` result and recommend the next `sub-spec`
   - do not automatically enter the next `sub-spec` without user confirmation

## Stage Gates

- Do not enter implementation before `master-spec`, current `phase-spec`, and current `sub-spec` are complete and confirmed
- Do not enter implementation before repository context, requirement, plan, and solution are clear enough
- Do not enter validation before review is complete unless the task is intentionally using a shortened flow
- Do not skip validation after implementation
- Do not finish a major stage without syncing the result into the knowledge base
- A stage is not considered fully complete until its checkpoint sync has actually run

## Standard Outputs

- repository exploration
- requirement definition
- master spec
- phase spec
- current sub-spec
- solution design
- implementation summary
- review report
- validation report
- current status
- knowledge-base record

## Good Fit

- greenfield product development
- rebuilding a difficult product with stronger process control
- long-context work that requires repeated user confirmation before implementation
- practicing a spec-driven OpenCode workflow on repositories like `knownbase_bk`

## Notes

- `master-spec` is the most important planning artifact for large projects and should be treated as the primary control document
- For small tasks, `program-planner` can produce a short `master-spec`
- For system rebuilds, `program-planner` and the confirmation gate should not be skipped
