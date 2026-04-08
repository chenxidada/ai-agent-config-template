# Master Spec Template

<!--
  This template is used by program-planner.
  It is the primary control document for all downstream planning and implementation.
  
  In CREATE mode: fill all sections from scratch.
  In UPDATE mode: append new phases; do NOT modify completed phases.
  
  Quality bar: task-planner must be able to read this document and produce a
  phase-spec WITHOUT needing to ask the orchestrator for clarification.
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
  
  Example:
  - SC-1: User can perform full CRUD on documents with sub-second response times
  - SC-2: AI-powered search returns relevant results for 90%+ of natural language queries
  - SC-3: System handles 1000+ documents without performance degradation
-->

## Product / System Scope

<!--
  High-level scope boundary. What IS and IS NOT in this project.
  
  Example:
  - In scope: Document management, folder organization, AI chat, knowledge graph
  - Out of scope: Multi-user collaboration, mobile app, offline mode
-->

## Top-Level Modules

<!--
  List the major modules/packages/domains of the system.
  For each module, give a one-line description of its responsibility.
  
  Example:
  | Module | Responsibility |
  |--------|---------------|
  | `apps/api` | Backend REST API (NestJS) |
  | `apps/web` | Frontend SPA (Next.js) |
  | `packages/shared` | Shared types and utilities |
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
  
  Use this table format:
  
  | Phase ID | Name | Goal | Key Deliverables | Est. Files | Status |
  |----------|------|------|-----------------|------------|--------|
  | phase-0-infra | Infrastructure | Database, auth, project scaffolding | Prisma schema, auth middleware, app shell | ~15 | complete |
  | phase-1-core-crud | Core CRUD | Full document lifecycle management | Folder/Doc/Tag CRUD APIs + management UI | ~53 | pending |
  | phase-2-ai-chat | AI Chat | Intelligent conversation with knowledge base | RAG pipeline, chat UI, embedding service | ~54 | pending |
  
  Status values: complete, in-progress, pending
  Est. Files: rough estimate of new files to create (helps gauge complexity)
-->

## Phase Dependencies

<!--
  Show how phases depend on each other. Use ASCII diagram for clarity.
  
  Example:
  ```
  phase-0-infra
    │
    ▼
  phase-1-core-crud
    │
    ├──► phase-2-ai-chat
    │
    └──► phase-3-advanced (can parallel with phase-2 partially)
  ```
-->

## New Dependency Summary

<!--
  List ALL new external dependencies (npm packages, services, infrastructure) across all phases.
  This gives a single view of what the project will pull in.
  
  Example:
  | Package | Version | Introduced In | Purpose |
  |---------|---------|--------------|---------|
  | meilisearch | ^0.41.0 | phase-1 | Full-text search client |
  | @codemirror/view | ^6.0.0 | phase-1 | Markdown editor |
  | @xyflow/react | ^12.0.0 | phase-3 | Knowledge graph visualization |
  
  If no new dependencies are needed, state "None" explicitly.
-->

## Key Constraints

<!--
  Technical, business, or timeline constraints that affect ALL phases.
  Sourced from requirements.md Constraints section.
  
  Example:
  - Must use PostgreSQL (existing infrastructure)
  - Frontend must be SSR-compatible (Next.js App Router)
  - All APIs must be RESTful with Swagger documentation
-->

## Key Decisions

<!--
  Architecture-level decisions that affect the overall project.
  Number them (KD-1, KD-2, ...) for traceability.
  
  Example:
  - KD-1: Use pgvector for vector storage instead of a dedicated vector database
  - KD-2: Monorepo structure with Turborepo
  - KD-3: Server-side streaming for AI chat (SSE, not WebSocket)
-->

## Risks / Assumptions

<!--
  Project-level risks and assumptions.
  
  | Risk | Impact | Likelihood | Mitigation |
  |------|--------|-----------|------------|
  | Third-party API rate limits | Feature degradation | Medium | Implement caching and retry |
  | Large document performance | Slow UI | Low | Virtualization + pagination |
-->

## Recommended Starting Phase

<!--
  Which phase should be implemented first and why.
  If phases are already in progress, state the current phase and next recommended action.
  
  Example:
  "Start with phase-1-core-crud. It establishes the data layer and management UI
  that all subsequent phases depend on. The first sub-spec should be the backend
  API layer (folder + document + tag CRUD) since the frontend depends on it."
-->
