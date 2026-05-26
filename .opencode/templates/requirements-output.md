# Requirements Output Template

<!-- 
  This template is used by requirement-analyst.
  In CREATE mode: fill all sections (for raw product ideas).
  In EXTRACT mode: fill all sections, with emphasis on Module Contracts (for completed design documents).
  In APPEND mode: add new content under a "## Requirement Update — <date>" section at the end.
-->

## Product Goal

<!-- What is the product trying to achieve? One paragraph. -->

## Problem Statement

<!-- What problem does this solve? Who has this problem? -->

## Desired End State

<!-- What does success look like when this is fully implemented? -->

## Target Users

<!-- Who are the primary users? List user types and their key characteristics. -->

## Core Scenarios

<!-- List the key user scenarios (user stories or use cases). Number them for easy reference. -->

## Intended Scope

<!-- What is the full intended scope of this product/feature? Be specific about what IS and IS NOT included. Do not artificially reduce to an MVP — capture the user's complete intent. -->

## Functional Areas

<!-- Group the requirements into functional areas. For each area, list the specific requirements. -->

## Module Contracts

> **Module Contracts** must follow the format defined in `.opencode/snippets/module-contract-format.md`.
> Copy the template from there — do NOT redefine the format here.
> Below, list the module contracts for this requirement following that format.

## Interface Freeze Order

<!--
  Define which module interfaces must be frozen (finalized) before dependent modules can begin implementation.
  
  | Freeze Group | Modules | Must Freeze Before | Freeze Criteria |
  |-------------|---------|-------------------|-----------------|
  | Group 1 | M01 (Core API) | M02-M08 can start | Header files compile, review approved |
  | Group 2 | M09-M11 (Service Layer) | M12-M15 can start | Public API review approved |
  
  Interface freeze means: method signatures, struct definitions, and enum values are locked.
  Adding new methods to extension interfaces is allowed. Changing existing signatures requires CR.
-->

## Non-Functional Requirements

<!--
  Performance, memory, reliability targets — ALL with measurement methods.
  
  | Requirement | Target | Measurement Method | Test Environment | Acceptable Deviation |
  |-------------|--------|-------------------|-----------------|---------------------|
  | API response time | < 50ms P99 | Load test with 1000 concurrent requests | any x86_64 Linux | First run may be 2x |
  | Cold start time | < 500ms | Process start to first request served | Target hardware | ±100ms |
-->

## Acceptance Criteria

<!-- 
  List explicit, testable acceptance criteria. Number them (AC-1, AC-2, ...).
  Each criterion should be:
  - Specific and measurable
  - Testable (can be verified by reviewer/validator)
  - Tied to a functional area, module contract, or scenario above
  
  Example:
  - AC-1: `sizeof(MessageHeader) == 16` compiles as static_assert
  - AC-2: API response time < 50ms (P99) under 1000 concurrent connections
  - AC-3: Service handles 1000 register/unregister ops/s without queue overflow
-->

## Non-Goals

<!-- What is explicitly NOT in scope? Only list things the user has confirmed are not needed, or things clearly unrelated to the stated goal. Do not preemptively defer features that belong to the user's core intent. -->

## Constraints

<!-- Technical, business, or timeline constraints that affect the implementation. -->

## Open Questions

<!-- 
  Questions that need human confirmation before proceeding.
  Number them (Q-1, Q-2, ...) so the user can reference them easily.
-->

## Risks / Assumptions

<!-- Known risks and assumptions that the design will be based on. -->

## Recommended Master Spec Direction

<!-- High-level guidance for program-planner on how to structure the master-spec phases. -->
