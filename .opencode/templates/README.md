# Templates

Output format templates used by subagents. Each template defines the structure and quality bar for a specific output file.

## Pipeline Output Templates

| Template | Used By | Output Path |
|----------|---------|-------------|
| `repo-exploration-output.md` | repo-explorer | `specs/exploration/repo-exploration.md` |
| `requirements-output.md` | requirement-analyst | `specs/requirements/requirements.md` |
| `master-spec.md` | program-planner | `specs/master-spec.md` |
| `phase-requirements.md` | program-planner | `specs/phases/<phase-id>/requirements.md` |
| `phase-spec.md` | task-planner | `specs/phases/<phase-id>/phase-spec.md` |
| `sub-spec.md` | solution-architect | `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md` |
| `solution-design-output.md` | solution-architect | `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md` |
| `implementation-summary.md` | implementer | `specs/phases/<phase-id>/slices/<sub-spec-id>/implementation-summary.md` |
| `review-report.md` | reviewer | `specs/phases/<phase-id>/slices/<sub-spec-id>/review-report.md` |
| `validation-report.md` | validator | `specs/phases/<phase-id>/slices/<sub-spec-id>/validation-report.md` |

## Analysis Templates

| Template | Used By | Output Path |
|----------|---------|-------------|
| `code-analysis-output.md` | code-analyst | `specs/analysis/code-analysis-*.md` |
| `analysis-progress.md` | code-analyst | `specs/analysis/.analysis-progress.json` |

## Infrastructure Templates

| Template | Used By | Purpose |
|----------|---------|---------|
| `current-status.md` | orchestrator | Pipeline state tracking |
| `knowledge-sync-note.md` | knowledge-manager | KB sync content format |
| `kb-rendering-guideline.md` | knowledge-manager | KB markdown rendering rules |
