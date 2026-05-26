# Master Spec Template

<!--
  This template is used by program-planner.
  It is the primary control document for all downstream planning and implementation.
  
  In CREATE mode: fill all sections from scratch.
  In UPDATE mode: append new phases; do NOT modify completed phases.
  
  Quality bar: task-planner must be able to read this document and produce a
  phase-spec WITHOUT needing to ask the orchestrator for clarification.
  
  CRITICAL: This document must carry forward ALL hard interface definitions,
  compile-time assertions, and runtime acceptance criteria from requirements.md.
  Summarizing technical constraints into prose is FORBIDDEN.
-->

## Project Goal

<!-- One paragraph describing the overall objective. Sourced from requirements.md Product Goal. -->

## Problem Statement

<!-- What problem does this project solve? Who has this problem? Sourced from requirements.md. -->

## Desired End State

<!-- What does the system look like when ALL phases are complete? 3-5 sentences. -->

## Success Criteria

<!--
  Measurable criteria that define project success. Number them (SC-1, SC-2, ...).
  MUST include quantitative targets with measurement methods.
  
  Example:
  - SC-1: API response time < 50ms (P99), measured by load test with 1000 concurrent requests
  - SC-2: Cold start to first request served < 500ms, measured by process timestamps
  - SC-3: Service handles ≥ 200 concurrent connections with event latency < 10ms (P99)
-->

## Product / System Scope

<!--
  High-level scope boundary. What IS and IS NOT in this project.
  
  Example:
  - In scope: Document management, folder organization, AI chat, knowledge graph
  - Out of scope: Multi-user collaboration, mobile app, offline mode
-->

## Top-Level Modules with Contracts

> **Module Contracts** must follow the format defined in `.opencode/snippets/module-contract-format.md`.
> Carry forward module contracts from `requirements.md` verbatim. Do NOT redefine them.
> For new modules introduced by added phases, create contracts following that format.

## Interface Freeze Order

<!--
  Define which module interfaces must be frozen before dependent modules can start.
  
  | Freeze Group | Modules | Must Freeze Before | Freeze Criteria |
  |-------------|---------|-------------------|-----------------|
  | Group 1 | M01 | M02-M08 start | Headers compile, review approved |
  | Group 2 | M09-M11 | M12-M15 start | Public API review approved |
  
  Freeze means: method signatures, struct definitions, enum values are locked.
  New methods on extension interfaces allowed. Existing signature changes require CR.
-->

## Capability Areas

<!--
  Group features into logical capability areas that may span multiple modules.
  
  Example:
  - Content Management: Folder CRUD, Document CRUD, Tag system
  - Search & Discovery: Full-text search, AI-powered search, knowledge graph
  - AI Integration: Chat interface, RAG pipeline, embedding service
-->

## Delivery Phases

<!--
  Break the project into sequential phases. Each phase should deliver usable, testable value.
  
  | Phase ID | Name | Goal | Modules Included | Status |
  |----------|------|------|-----------------|--------|
  | phase-1-foundation | Foundation | Core abstractions + build system | M01-M03 | pending |
  
  Status values: complete, in-progress, pending
  
  Do NOT include effort estimates (person-days) unless explicitly requested.
-->

## Phase Dependencies

<!--
  Show how phases depend on each other. Use mermaid or ASCII diagram.
-->

## Per-Phase Acceptance Criteria

<!--
  For each phase, define measurable acceptance criteria with test methods.
  
  ### Phase 1 Acceptance
  
  | # | Criterion | Target | Measurement Method | Test Environment |
  |---|-----------|--------|-------------------|-----------------|
  | 1 | Core interfaces compile | zero warnings | -Wall -Wextra -Werror | any x86_64 Linux |
  | 2 | Buffer is move-only | compile check | static_assert(!is_copy_constructible) | compile time |
  
  Do NOT write vague criteria like "basic framework works" or "service is functional".
-->

## New Dependency Summary

<!--
  List ALL new external dependencies across all phases.
  
  | Package | Version | Introduced In | Purpose |
  |---------|---------|--------------|---------|
  | example-lib | ^2.0.0 | phase-1 | Core functionality |
  
  If no new dependencies are needed, state "None" explicitly.
-->

## Key Constraints

<!--
  Technical, business, or timeline constraints that affect ALL phases.
  Sourced from requirements.md and design document.
-->

## Key Decisions

<!--
  Architecture-level decisions that affect the overall project.
  Number them (KD-1, KD-2, ...) for traceability.
  Reference the design document decision numbers if available.
-->

## Risks / Assumptions

<!--
  Project-level risks and assumptions.
  
  | Risk | Impact | Likelihood | Mitigation |
  |------|--------|-----------|------------|
-->

## Recommended Starting Phase

<!--
  Which phase should be implemented first and why.
-->
