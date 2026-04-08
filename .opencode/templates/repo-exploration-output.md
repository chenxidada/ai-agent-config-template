# Repository Exploration Output Template

<!--
  This template is used by repo-explorer.
  It is typically the FIRST document produced in the pipeline.
  
  Downstream consumers:
  - requirement-analyst: understands what already exists before defining requirements
  - solution-architect: knows the codebase conventions before designing
  - implementer: knows where to put new code and what patterns to follow
  
  Quality bar: requirement-analyst should be able to read this document and
  understand the current system state without needing to explore the repo themselves.
  
  Rules:
  - Distinguish CONFIRMED FACTS from HYPOTHESES (mark hypotheses explicitly)
  - Include actual file paths — do not use vague references like "the config file"
  - Focus on what is RELEVANT TO THE TASK, not a full repo inventory
-->

## Task Context

<!--
  What task or feature prompted this exploration?
  One paragraph summarizing what we're looking for in the repo.
-->

## Repository Overview

<!--
  High-level structure of the repository.
  Include: language, framework, package manager, monorepo structure (if any).
  
  Example:
  - Language: TypeScript
  - Framework: NestJS (backend), Next.js 14 App Router (frontend)
  - Package manager: pnpm with Turborepo monorepo
  - Structure: `apps/api/`, `apps/web/`, `packages/shared/`
  - Database: PostgreSQL with Prisma ORM
  - Test framework: Jest (backend), Vitest (frontend)
-->

## Most Relevant Areas

<!--
  Files and directories most relevant to the task at hand.
  For each area, explain WHY it matters and what it contains.
  
  Example:
  | Path | What It Contains | Relevance |
  |------|-----------------|-----------|
  | `apps/api/src/modules/documents/` | Document CRUD service + controller | Direct modification target |
  | `apps/api/prisma/schema.prisma` | Database schema definitions | Need to add new fields/tables |
  | `apps/web/components/documents/` | Document list and editor components | UI modification target |
  | `packages/shared/src/types/document.ts` | Shared TypeScript types | Must update for new fields |
-->

## Key Entry Points / Call Paths

<!--
  Trace the most important code paths relevant to the task.
  Show how a request flows from entry point to data layer.
  
  Example:
  ```
  User clicks "Create Document"
  → apps/web/components/documents/create-dialog.tsx
  → apps/web/hooks/use-documents.ts (API call)
  → apps/api/src/modules/documents/documents.controller.ts (POST /api/documents)
  → apps/api/src/modules/documents/documents.service.ts (create method)
  → Prisma → PostgreSQL
  ```
  
  List 1-3 relevant call paths. More is unnecessary.
-->

## Likely Impact Surface

<!--
  What existing code will need to change or could be affected?
  
  Example:
  - `documents.service.ts` — needs new method for export
  - `document.types.ts` — needs ExportConfig interface
  - `app.module.ts` — may need new module import
  - `sidebar.tsx` — needs new navigation entry (LOW risk, additive only)
-->

## Existing Constraints / Conventions

<!--
  Patterns and conventions already established in the codebase that new code should follow.
  
  Example:
  - API routes follow RESTful conventions: `GET /api/{resource}`, `POST /api/{resource}`, etc.
  - All DTOs use class-validator decorators
  - Frontend state management uses Zustand stores
  - All components use shadcn/ui component library
  - Error handling uses a global exception filter (apps/api/src/filters/http-exception.filter.ts)
  - File naming: kebab-case for files, PascalCase for components
-->

## Risks / Unknowns

<!--
  Things that could cause problems or need further investigation.
  Mark each as CONFIRMED or HYPOTHESIS.
  
  Example:
  - [CONFIRMED] No existing export functionality — must build from scratch
  - [HYPOTHESIS] The Document model may need a `status` field for export state tracking
  - [CONFIRMED] Current Prisma schema has no migration for vector columns
  - [UNKNOWN] Whether the frontend build pipeline supports dynamic imports for code splitting
-->

## Recommended Next Reads

<!--
  Specific files that downstream agents (requirement-analyst, solution-architect) 
  should read for deeper context. Prioritize by importance.
  
  Example:
  1. `apps/api/prisma/schema.prisma` — understand current data model (MUST READ)
  2. `apps/api/src/modules/documents/documents.service.ts` — current CRUD patterns (MUST READ)
  3. `apps/web/components/documents/document-list.tsx` — current UI patterns (SHOULD READ)
  4. `packages/shared/src/types/index.ts` — shared type conventions (SHOULD READ)
-->
