# Analysis Progress File

This document describes the format for `specs/analysis/.analysis-progress.json`, used by `code-analyst` to track incremental analysis progress and enable recovery after context compression.

## Purpose

When analyzing large codebases, the analysis may be interrupted by context compression. This progress file allows `code-analyst` to:

1. Resume from where it left off
2. Skip already-analyzed modules
3. Preserve partial findings
4. Complete the full analysis across multiple dispatch cycles

## File Location

```
specs/analysis/.analysis-progress.json
```

The file is prefixed with `.` to indicate it's a working file, not a final deliverable.

## Schema

```json
{
  "analysisId": "string (UUID)",
  "scope": "string (full-repo | specific path)",
  "focusAngle": "string | null",
  "outputFile": "string (path to output markdown)",
  "status": "in_progress | completed | interrupted",
  "phase": "discovery | module_analysis | synthesis",
  "totalModules": ["array of module paths"],
  "completedModules": ["array of completed module paths"],
  "currentModule": "string | null",
  "moduleQueue": ["array of remaining module paths"],
  "partialFindings": {
    "architecture": "string (accumulated architecture findings)",
    "patterns": "string (accumulated pattern findings)",
    "dependencies": "string (accumulated dependency findings)",
    "dataFlow": "string (accumulated data flow findings)",
    "codeQuality": "string (accumulated code quality findings)",
    "risks": "string (accumulated risk findings)",
    "keyFiles": ["array of key file paths identified"]
  },
  "statistics": {
    "totalFiles": "number",
    "analyzedFiles": "number",
    "totalLines": "number",
    "analyzedLines": "number"
  },
  "timestamps": {
    "started": "ISO 8601 timestamp",
    "lastUpdated": "ISO 8601 timestamp",
    "completed": "ISO 8601 timestamp | null"
  },
  "resumeHint": "string (human-readable hint for resumption)"
}
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `analysisId` | Yes | Unique identifier for this analysis run |
| `scope` | Yes | What is being analyzed: "full-repo" or a specific path |
| `focusAngle` | No | Specific analysis angle if any (e.g., "data-flow", "security") |
| `outputFile` | Yes | Path to the output markdown file |
| `status` | Yes | Current status: `in_progress`, `completed`, or `interrupted` |
| `phase` | Yes | Current phase: `discovery`, `module_analysis`, or `synthesis` |
| `totalModules` | Yes | All modules identified for analysis |
| `completedModules` | Yes | Modules that have been fully analyzed |
| `currentModule` | No | Module currently being analyzed (null if between modules) |
| `moduleQueue` | Yes | Modules remaining to be analyzed |
| `partialFindings` | Yes | Accumulated findings from completed modules |
| `statistics` | No | Quantitative progress metrics |
| `timestamps` | Yes | Timing information |
| `resumeHint` | No | Human-readable description of how to continue |

## Status Values

| Status | Meaning |
|--------|---------|
| `in_progress` | Analysis is actively running or can be resumed |
| `completed` | Analysis finished successfully, final report written |
| `interrupted` | Analysis was interrupted (e.g., by error), may need cleanup |

## Phase Values

| Phase | Description |
|-------|-------------|
| `discovery` | Scanning directories, building module list, estimating complexity |
| `module_analysis` | Analyzing modules one by one |
| `synthesis` | All modules analyzed, synthesizing final report |

## Example Progress File

```json
{
  "analysisId": "a1b2c3d4-5678-90ab-cdef-123456789abc",
  "scope": "full-repo",
  "focusAngle": null,
  "outputFile": "specs/analysis/code-analysis-full.md",
  "status": "in_progress",
  "phase": "module_analysis",
  "totalModules": [
    "src/core/",
    "src/api/",
    "src/services/",
    "src/utils/",
    "src/components/",
    "lib/",
    "tests/"
  ],
  "completedModules": [
    "src/core/",
    "src/api/",
    "src/services/"
  ],
  "currentModule": "src/utils/",
  "moduleQueue": [
    "src/utils/",
    "src/components/",
    "lib/",
    "tests/"
  ],
  "partialFindings": {
    "architecture": "Layered architecture with clear separation: core (domain logic), api (REST endpoints), services (business logic). Core has no external dependencies. API depends on services. Services depend on core.",
    "patterns": "Repository pattern in services/. Factory pattern for object creation in core/. Observer pattern for event handling.",
    "dependencies": "Express.js for API layer. PostgreSQL via node-postgres. Redis for caching. No ORM - raw SQL queries.",
    "dataFlow": "Request → API controller → Service → Repository → Database. Response follows reverse path. Events published to Redis pub/sub.",
    "codeQuality": "Good separation of concerns. Some services have high cyclomatic complexity. Error handling inconsistent between modules.",
    "risks": "No input validation at API boundary. SQL queries constructed with string interpolation in some places.",
    "keyFiles": [
      "src/core/domain/entities.ts",
      "src/api/routes/index.ts",
      "src/services/userService.ts"
    ]
  },
  "statistics": {
    "totalFiles": 156,
    "analyzedFiles": 78,
    "totalLines": 24500,
    "analyzedLines": 12300
  },
  "timestamps": {
    "started": "2026-04-04T09:15:00Z",
    "lastUpdated": "2026-04-04T10:30:00Z",
    "completed": null
  },
  "resumeHint": "3 of 7 modules complete (~43%). Continue from src/utils/. Core architecture documented. Focus remaining analysis on components, lib, and tests."
}
```

## Usage by code-analyst

### On Fresh Start

1. Check if progress file exists
2. If not, create new progress file with `status: in_progress`, `phase: discovery`
3. Run discovery phase, populate `totalModules`
4. Transition to `module_analysis` phase

### During Analysis

1. Before analyzing each module, update `currentModule`
2. After completing each module:
   - Add to `completedModules`
   - Remove from `moduleQueue`
   - Update `partialFindings`
   - Update `statistics`
   - Update `lastUpdated`
   - Set `currentModule` to next in queue or null

### On Context Pressure

1. Save current state immediately
2. Update `resumeHint` with clear continuation instructions
3. Return to Orchestrator with `status: context_pressure`

### On Resume

1. Read progress file
2. Verify `scope` and `focusAngle` match dispatch parameters
3. If match: continue from `currentModule` or next in `moduleQueue`
4. If mismatch: report to Orchestrator for decision

### On Completion

1. Set `status: completed`
2. Set `phase: synthesis`
3. Set `timestamps.completed`
4. Optionally delete or archive progress file

## Orchestrator Handling

The Orchestrator should:

1. Check for existing progress file before dispatching `code-analyst`
2. If progress file exists with `status: in_progress`:
   - Add `resume: true` to dispatch prompt
   - Include progress file path
3. If `code-analyst` returns `context_pressure`:
   - Update `current-status.md`
   - Re-dispatch with `resume: true` after compression recovery
4. Track retry count to avoid infinite loops (max 5 resume cycles)
