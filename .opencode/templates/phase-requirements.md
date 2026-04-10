# Phase Requirements Template

<!--
  This template is used by program-planner to extract phase-specific requirements
  from the overall requirements document.
  
  Purpose: Extract the specific requirements from the full project scope that THIS phase must deliver completely.
  Downstream consumers: task-planner (for sub-spec breakdown), solution-architect (for design scope).
  
  Rules:
  - Every requirement listed here MUST trace back to a requirement in specs/requirements/requirements.md
  - Do NOT invent new requirements — only extract and refine existing ones
  - Use the same numbering (AC-N, Q-N) from the parent requirements where applicable
  - If a requirement spans multiple phases, note which part belongs to THIS phase
-->

## Phase Identity

<!-- 
  Phase ID and name, matching the master-spec entry.
  Example:
  - Phase ID: phase-1-core-crud
  - Phase Name: Core CRUD Operations
  - Parent requirement sections: Functional Areas §1, §2; Acceptance Criteria AC-1 through AC-8
-->

## Phase Goal

<!-- 
  One paragraph: what does completing this phase achieve?
  Must be a subset of the overall Product Goal from requirements.md.
-->

## Included Requirements

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

## Acceptance Criteria for This Phase

<!--
  Extract ONLY the acceptance criteria from the parent requirements that this phase must satisfy.
  Use checklist format so task-planner and validator can directly reference them.
  
  Example:
  - [ ] AC-1: User can create, rename, and delete folders
  - [ ] AC-3: User can create documents and edit in Markdown
  - [ ] AC-4: Documents can be moved between folders
  - [ ] AC-7: All CRUD APIs return proper error responses
-->

## Excluded from This Phase

<!--
  Requirements from the parent document that are explicitly NOT in this phase.
  Reference which phase they belong to (if known).
  
  Example:
  - AC-9: Full-text search — deferred to Phase 2
  - AC-12: AI-powered suggestions — deferred to Phase 3
  - FA-5: Export functionality — deferred to Phase 3
-->

## Constraints Inherited from Requirements

<!--
  Relevant constraints from the parent requirements.md that affect this phase.
  Only include constraints that are actionable for this phase's implementation.
-->

## Open Questions Relevant to This Phase

<!--
  Extract open questions (Q-N) from the parent requirements that must be resolved
  before or during this phase. Add any new phase-specific questions.
  
  Example:
  - Q-1: (from parent) Should folder delete cascade to documents or just unlink?
  - Q-P1-1: (new) Should the API support batch document creation in this phase?
-->

## Dependencies

<!--
  What must be in place before this phase can start?
  
  Example:
  - Phase 0 infrastructure (database, auth) must be complete
  - Prisma schema for Folder, Document, Tag tables must exist
-->
