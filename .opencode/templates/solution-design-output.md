# Solution Design Output Template

<!--
  This template is used by solution-architect to document the technical design.
  Implementer depends on this document for implementation guidance.
  Reviewer uses it to verify implementation adherence.
  Be specific enough that the implementer can work without guessing.
-->

## Scope Covered

<!-- 
  Which sub-spec does this design cover?
  Reference the phase-spec and requirements that drive this design.
-->

## Architecture Summary

<!-- 
  High-level technical approach in 3-5 sentences.
  Example: "Implement a streaming CSV export pipeline using Node.js Transform streams. 
  The export service sits between the data layer and the HTTP response, allowing 
  progressive data writing without buffering the entire dataset in memory."
-->

## Core Entities / Data Model

<!-- 
  New or modified data structures, types, interfaces.
  Include field names, types, and relationships.
  
  Example:
  ```typescript
  interface ExportConfig {
    format: 'csv' | 'json';
    columns: string[];
    filters: FilterCriteria;
    maxRows?: number;
  }
  ```
-->

## API Domains

<!-- 
  New or modified API endpoints, function signatures, or component interfaces.
  Include request/response shapes.
  
  Example:
  - POST /api/export — Request: ExportConfig, Response: StreamingDownload
  - ExportButton component — Props: { dataSource: string, onComplete: () => void }
-->

## Implementation Approach

<!--
  Step-by-step description of how to implement this design.
  Be specific enough that the implementer knows:
  - Which files to create or modify (exact paths)
  - What the key logic should look like (code skeletons for non-trivial parts)
  - How components connect to each other
  
  Example:
  1. Create `apps/api/src/modules/export/export.service.ts` with the ExportService class
  2. Add the POST /api/export route in `apps/api/src/modules/export/export.controller.ts`
  3. Create `apps/web/components/export/export-button.tsx` that calls the export API
  4. Add error handling for export-specific errors in the service layer
-->

### File Output Plan

<!--
  CRITICAL: List every file that will be created or modified.
  This is the implementer's primary work checklist.
  
  Example:
  
  **New files:**
  ```
  apps/api/src/modules/export/
  ├── export.module.ts
  ├── export.service.ts
  ├── export.controller.ts
  └── dto/
      ├── export-config.dto.ts
      └── export-result.dto.ts
  apps/web/components/export/
  ├── export-button.tsx
  └── export-dialog.tsx
  packages/shared/src/types/
  └── export.ts
  ```
  
  **Modified files:**
  ```
  apps/api/src/app.module.ts          — import ExportModule
  apps/web/components/layout/sidebar.tsx — add export nav entry
  packages/shared/src/types/index.ts   — re-export export types
  ```
-->

### Code Skeletons

<!--
  For key non-trivial components, provide code skeletons showing:
  - Class/function signatures
  - Core logic flow (pseudocode or simplified real code)
  - Important type definitions (DTOs, interfaces)
  
  Do NOT write full implementation code. Write enough that the implementer
  understands the design intent without ambiguity.
  
  Example:
  
  ```typescript
  // apps/api/src/modules/export/dto/export-config.dto.ts
  export class ExportConfigDto {
    @IsEnum(['csv', 'json'])
    format: 'csv' | 'json';

    @IsArray()
    @IsString({ each: true })
    columns: string[];

    @IsOptional()
    @IsInt()
    @Min(1)
    maxRows?: number;
  }
  ```
  
  ```typescript
  // apps/api/src/modules/export/export.service.ts
  @Injectable()
  export class ExportService {
    constructor(private prisma: PrismaService) {}

    async exportDocuments(config: ExportConfigDto): Promise<StreamableFile> {
      // 1. Query documents with pagination (avoid loading all into memory)
      // 2. Transform to selected format using streaming pipeline
      // 3. Return as StreamableFile for HTTP streaming
    }
  }
  ```
  
  ```tsx
  // apps/web/components/export/export-button.tsx
  interface ExportButtonProps {
    dataSource: string;
    onComplete?: () => void;
  }
  
  export function ExportButton({ dataSource, onComplete }: ExportButtonProps) {
    // 1. Open export config dialog on click
    // 2. Call POST /api/export with user-selected config
    // 3. Handle streaming download
    // 4. Show success/error toast
  }
  ```
  
  Only include skeletons for NEW or COMPLEX components.
  Simple CRUD or boilerplate does not need skeletons.
-->

## External Dependencies

<!-- 
  Any new libraries, services, or infrastructure required.
  Example:
  - csv-stringify (npm) — for CSV serialization
  - No new infrastructure required
-->

## Risky Subsystems

<!-- 
  Parts of the design that are higher risk or need extra attention.
  Example:
  - Memory usage during large exports — need streaming, not buffering
  - CSV encoding for non-ASCII characters — must use UTF-8 BOM
-->

## Tradeoffs / Alternatives

<!-- 
  What alternatives were considered? Why was this approach chosen?
  Example:
  - Alternative: Client-side CSV generation with Papa Parse
  - Rejected because: Server-side needed for data filtering and access control
  - Tradeoff: Server-side streaming adds complexity but handles large datasets
-->

## Validation Plan

<!--
  This section is CRITICAL — it drives the entire review and validation process.
  Design specific test scenarios that downstream agents (reviewer, validator) will use.
  
  Use this table format:
  
  | ID | Type | Scenario | Expected Result | Priority |
  |----|------|----------|----------------|----------|
  | VP-1 | functional | Export 100 rows as CSV | File downloads with correct headers and data | must |
  | VP-2 | boundary | Export with 0 rows selected | User sees "no data" message, no file created | must |
  | VP-3 | error | Export when API is unreachable | Error toast shown, no partial file | must |
  | VP-4 | regression | Existing data views still load correctly | No changes to data display | must |
  | VP-5 | visual | Export button renders on data page | Button visible, correct styling | should |
  
  Types: functional, boundary, error, regression, visual, performance
  Priority: must (blocks completion), should (recommended), could (nice to have)
-->

## Decisions Requiring Confirmation

<!-- 
  Any design decisions that need user approval before implementation begins.
  Example:
  - Should we support Excel (.xlsx) format in addition to CSV?
  - Maximum export size: 10MB or unlimited with pagination?
-->

## Recommended Next Step

<!-- 
  What should happen after this design is approved?
  Usually: "Proceed to implementation of this sub-spec."
-->
