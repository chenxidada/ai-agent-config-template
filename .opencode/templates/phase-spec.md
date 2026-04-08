# Phase Spec Template

<!--
  This template is used by task-planner.
  It breaks a single phase from the master-spec into executable sub-spec units.
  
  Downstream consumers:
  - solution-architect: picks sub-specs to design
  - implementer: implements approved sub-specs
  - orchestrator: tracks phase progress
  
  Quality bar: solution-architect must be able to read this document and
  understand exactly what each sub-spec should deliver, without guessing.
-->

## Phase Goal

<!--
  One paragraph: what does completing this phase achieve?
  Must align with the phase description in master-spec.md.
-->

## In Scope

<!--
  Specific capabilities and features that this phase delivers.
  Reference the phase-requirements.md entries where applicable.
  
  Example:
  - Folder CRUD (create, rename, move, delete with cascade)
  - Document CRUD (create, edit, move, soft-delete, restore)
  - Tag CRUD (create, edit, delete, assign to documents)
  - REST API with Swagger documentation for all endpoints
-->

## Out Of Scope

<!--
  Features explicitly deferred to later phases. Prevents scope creep.
  
  Example:
  - Full-text search (Phase 2)
  - AI chat integration (Phase 3)
  - Document version history (Phase 3)
-->

## Related Modules

<!--
  Which codebase modules/packages are affected by this phase?
  
  Example:
  - `apps/api/src/modules/documents/` — new module
  - `apps/api/src/modules/folders/` — new module
  - `apps/web/components/documents/` — new components
  - `packages/shared/src/types/` — new type definitions
-->

## Sub-Spec Backlog

<!--
  Break the phase into ordered sub-spec units. Each sub-spec should be:
  - Small enough to implement in one cycle (typically 1-3 sessions)
  - Large enough to deliver testable, meaningful value
  - Independently verifiable (has its own acceptance criteria)
  
  Use this table format:
  
  | # | Sub-Spec ID | Name | Deliverables | Dependencies | Est. Files | Status |
  |---|------------|------|-------------|-------------|------------|--------|
  | 1 | backend-crud | Backend CRUD APIs | Folder/Doc/Tag REST endpoints + Swagger | none | ~20 | pending |
  | 2 | frontend-shell | Frontend Layout Shell | App shell, sidebar, routing | #1 (needs API) | ~5 | pending |
  | 3 | frontend-crud | Frontend CRUD UI | Folder tree, doc list, tag manager | #1, #2 | ~15 | pending |
  | 4 | search-integration | Search & Preview | Meilisearch setup, search UI, doc preview | #1, #3 | ~10 | pending |
  
  Sub-Spec ID: kebab-case, used as directory name in specs/phases/<phase-id>/slices/<sub-spec-id>/
  Dependencies: reference by # number; "none" if independent
  Est. Files: rough count of new files (helps gauge complexity)
  Status: pending, in-progress, complete, blocked
-->

## Execution Order

<!--
  Show the recommended execution sequence with dependency arrows.
  Use ASCII diagram for clarity when sub-specs have parallel paths.
  
  Example:
  ```
  #1 backend-crud
    │
    ├──► #2 frontend-shell ──► #3 frontend-crud
    │
    └──► #4 search-integration (can parallel with #2/#3)
  ```
  
  If strictly sequential, a numbered list is sufficient:
  1. #1 backend-crud
  2. #2 frontend-shell
  3. #3 frontend-crud
  4. #4 search-integration
-->

## Entry Criteria

<!--
  What must be true BEFORE this phase can start?
  
  Example:
  - [ ] Previous phase infrastructure is deployed and verified
  - [ ] Database schema migrations have been applied
  - [ ] Required environment variables are configured
-->

## Exit Criteria

<!--
  What must be true for this phase to be considered COMPLETE?
  Use checklist format — validator will check these directly.
  
  Example:
  - [ ] All sub-specs implemented and reviewed
  - [ ] All acceptance criteria from phase-requirements.md satisfied
  - [ ] Build passes without errors
  - [ ] No critical or high-severity issues in review reports
  - [ ] API documentation is complete and accurate
-->

## Risks / Open Questions

<!--
  Phase-specific risks and unresolved questions.
  
  Example:
  - Risk: Meilisearch Chinese tokenization may need custom configuration
  - Q: Should folder delete cascade to child documents or just unlink them?
  - Q: What is the maximum document size we need to support?
-->

## Current Recommended Sub-Spec

<!--
  Which sub-spec should solution-architect design NEXT, and why?
  
  Example:
  "Start with #1 backend-crud. It has no dependencies and establishes the data
  layer that all other sub-specs in this phase depend on. The scope is well-defined:
  3 resource types (folder, document, tag) with standard CRUD operations."
-->
