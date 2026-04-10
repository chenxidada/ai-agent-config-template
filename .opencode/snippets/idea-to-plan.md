# idea-to-plan

Use this workflow when a user starts from a product idea. This pipeline does NOT include implementation -- it stops after planning and design.

The Orchestrator dispatches each stage via the Task tool.

## Stages

### Stage 1: repo-explorer

- **Dispatch**: Pass the idea description and any existing system context
- **Output file**: `specs/exploration/repo-exploration.md`
- **Expect back**: Summary of existing repository or system constraints

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + user's idea description
- **Mode context**: "Analyze this idea and create a requirements document"
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Read existing** (if append): `specs/requirements/requirements.md`
- **Output file**: `specs/requirements/requirements.md`
- **Expect back**: Summary of goals, users, intended scope, non-goals, open questions

### Stage 3: program-planner

- **Dispatch**: Pass requirement-analyst summary + user decisions on open questions
- **Mode context**: First-time or append (based on whether master-spec exists)
- **Read upstream**: `specs/requirements/requirements.md`, `specs/exploration/repo-exploration.md`
- **Read existing** (if append): `specs/master-spec.md`
- **Output files**:
  - `specs/master-spec.md` (create or update)
  - `specs/phases/<phase-id>/requirements.md` (per new phase)
- **Expect back**: Summary of modules, phases, recommended starting phase

### Stage 4: task-planner

- **Dispatch**: Pass program-planner summary + recommended first phase
- **Read upstream**: `specs/master-spec.md`, `specs/phases/<phase-id>/requirements.md`
- **Output file**: `specs/phases/<phase-id>/phase-spec.md`
- **Expect back**: Summary of sub-specs, recommended build order

### Stage 5: solution-architect

- **Dispatch**: Pass task-planner summary + recommended first slice
- **Read upstream**: `specs/phases/<phase-id>/phase-spec.md`, `specs/phases/<phase-id>/requirements.md`
- **Output files**: `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`, `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Expect back**: Summary of proposed technical design for the intended scope

### Stage 6: knowledge-manager

- **Dispatch**: Pass requirement + architecture summaries
- **Action**: Save requirement and architecture milestones as Topic Doc and Decision Doc
- **Expect back**: Confirmation of sync

### Human Gate (final presentation)

- **Present**: Complete idea analysis: requirement summary, phase breakdown, technical approach, key risks
- **Purpose**: User reviews the idea analysis. No auto-implementation.
- **Next steps**: User can choose to start `/feature` or `/rebuild` to proceed to implementation

## Expected Outputs

- `specs/exploration/repo-exploration.md` - Repository/system context
- `specs/requirements/requirements.md` - Requirement definition
- `specs/master-spec.md` - Master plan with phase breakdown
- `specs/phases/<phase-id>/requirements.md` - Phase-specific requirements
- `specs/phases/<phase-id>/phase-spec.md` - Phase task breakdown
- `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md` - Technical spec with Validation Plan
- `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md` - Solution design
- Knowledge base records (Topic Doc, Decision Doc)
