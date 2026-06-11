# Phase Requirements Template

<!--
  This template is used by requirement-analyst in PER-PHASE EXTRACT mode
  to extract phase-specific requirements from the overall requirements document
  and the original design document.
  
  Purpose: Extract the specific requirements from the full project scope that THIS phase must deliver completely,
  including hard module contracts, non-functional requirements, and risks — with the same rigor as the overall
  requirements document.
  
  Downstream consumers: task-planner (for sub-spec breakdown), solution-architect (for design scope),
  implementer (for hard interface definitions), reviewer/validator (for acceptance criteria).
  
  Rules:
  - Every requirement listed here MUST trace back to a requirement in specs/requirements/requirements.md
    or the original design document — cite source section and line numbers
  - Do NOT invent new requirements — only extract and refine existing ones
  - Use the same numbering (AC-N, Q-N) from the parent requirements where applicable
  - If a requirement spans multiple phases, note which part belongs to THIS phase
  - ALL module contracts from the parent requirements that belong to this phase MUST appear verbatim
  - Quantitative constraints MUST NOT be summarized into prose — keep exact values
-->

## Phase Identity

<!-- REQUIRED -->
<!-- 
  Phase ID and name, matching the master-spec entry.
  Example:
  - Phase ID: phase-1-core-crud
  - Phase Name: Core CRUD Operations
  - Parent requirement sections: Functional Areas §1, §2; Acceptance Criteria AC-1 through AC-8
-->

## Phase Goal

<!-- REQUIRED -->
<!-- 
  One paragraph: what does completing this phase achieve?
  Must be a subset of the overall Product Goal from requirements.md.
-->

## Problem Statement (Phase-Specific)

<!-- REQUIRED -->
<!--
  What specific problem does THIS phase solve? What is the current state before this phase?
  Who is blocked by this phase not being complete?
-->

## Desired End State (Phase-Specific)

<!-- REQUIRED -->
<!--
  What does success look like when THIS phase is complete?
  What becomes possible that was not possible before?
-->

## Included Requirements

<!-- REQUIRED -->
<!--
  List the specific requirements from the parent requirements.md that belong to this phase.
  Group by functional area. Reference the original numbering.
  
  Example:
  
  ### Folder Management (from Functional Area §1)
  - FA-1.1: Create folders with name and optional parent
  - FA-1.2: Rename and move folders
  - FA-1.3: Delete folders (cascade behavior TBD)
  
  ### Document CRUD (from Functional Area §2)
  - FA-2.1: Create documents with title and markdown content
  - FA-2.2: Update document content with auto-save
  - FA-2.3: Move documents between folders
  - FA-2.4: Soft-delete and restore documents
-->

## Module Contracts

<!-- REQUIRED if parent requirements.md contains Module Contracts for this phase's modules -->
<!--
  Extract verbatim from the parent requirements.md and/or original design document.
  Follow the format defined in .opencode/snippets/module-contract-format.md.
  
  For each module contract, include:
  - Hard interface definitions (exact struct fields, method signatures, type constraints)
  - Compile-time acceptance criteria (static_assert conditions, -Wall -Werror requirements)
  - Runtime acceptance criteria (latency targets, throughput targets, memory limits —
    with measurement method and test environment)
  - Downstream commitments (what this module promises to its dependents)
  - Source traceability (exact section + line references in requirements.md or design document)

  CRITICAL: Do NOT summarize quantitative constraints into prose.
  If the source says `< 100μs`, output must say `< 100μs`, not "low latency".
  If the source says `static_assert(sizeof(X) == N)`, include it verbatim.
-->

## Non-Functional Requirements (Phase-Specific)

<!-- REQUIRED -->
<!--
  Extract NFRs from the parent requirements that are relevant to THIS phase.
  ALL entries MUST include measurement methods.

  | Requirement | Target | Measurement Method | Test Environment | Acceptable Deviation |
  |-------------|--------|-------------------|-----------------|---------------------|
  | API response time | < 50ms P99 | Load test with 1000 concurrent requests | any x86_64 Linux | First run may be 2x |
  | Cold start time | < 500ms | Process start to first request served | Target hardware | ±100ms |
-->

## Acceptance Criteria for This Phase

<!-- REQUIRED -->
<!--
  Extract ONLY the acceptance criteria from the parent requirements that this phase must satisfy.
  Use checklist format so task-planner and validator can directly reference them.
  Each criterion must be: specific, measurable, testable.
  
  Example:
  - [ ] AC-1: User can create, rename, and delete folders
  - [ ] AC-3: User can create documents and edit in Markdown
  - [ ] AC-4: Documents can be moved between folders
  - [ ] AC-7: All CRUD APIs return proper error responses
-->

## Excluded from This Phase

<!-- REQUIRED -->
<!--
  Requirements from the parent document that are explicitly NOT in this phase.
  Reference which phase they belong to (if known).
  
  Example:
  - AC-9: Full-text search — deferred to Phase 2
  - AC-12: AI-powered suggestions — deferred to Phase 3
  - FA-5: Export functionality — deferred to Phase 3
-->

## Constraints Inherited from Requirements

<!-- REQUIRED if parent requirements has constraints -->
<!--
  Relevant constraints from the parent requirements.md that affect this phase.
  Only include constraints that are actionable for this phase's implementation.
  
  | Constraint ID | Constraint | Source |
  |:------------:|------------|:------:|
  | GC-1 | C++17 (no C++20) | requirements.md §Constraints |
-->

## Risks / Assumptions (Phase-Specific)

<!-- REQUIRED -->
<!--
  Known risks and assumptions specific to THIS phase.
  
  | # | Risk | Severity | Impact | Mitigation |
  |---|------|:--------:|--------|-----------|
  | PR-1 | Description | CRITICAL/HIGH/MEDIUM/LOW | What happens if it occurs | How to mitigate |
  
  ### Assumptions
  - Assumption 1
  - Assumption 2
-->

## Open Questions Relevant to This Phase

<!-- REQUIRED if parent requirements has open questions for this phase -->
<!--
  Extract open questions (Q-N) from the parent requirements that must be resolved
  before or during this phase. Add any new phase-specific questions.
  
  Example:
  - Q-1: (from parent) Should folder delete cascade to documents or just unlink?
  - Q-P1-1: (new) Should the API support batch document creation in this phase?
-->

## Source Traceability

<!-- REQUIRED -->
<!--
  Map every requirement in this document back to its source.
  
  | This Document | Source Document | Section / Lines |
  |--------------|----------------|-----------------|
  | §Module Contracts M01 | requirements.md | §Module Contracts M01 |
  | §Module Contracts M01 | design-doc/transport.md | §3.2 L142-178 |
  | §NFR latency < 100μs | requirements.md | §Non-Functional Requirements |
  | §AC-1 through AC-5 | requirements.md | §Acceptance Criteria |
-->

## User-Confirmed Decisions

<!-- LOCKED: 以下决策由用户在整体需求阶段确认。Agent 不得修改。如确需修改，必须通过 Human Gate 提请用户确认。 -->
<!--
  Carry forward any User-Confirmed Decisions from the parent requirements.md
  that are relevant to this phase.
-->

## Dependencies

<!-- REQUIRED -->
<!--
  What must be in place before this phase can start?
  
  Example:
  - Phase 0 infrastructure (database, auth) must be complete
  - Prisma schema for Folder, Document, Tag tables must exist
-->
