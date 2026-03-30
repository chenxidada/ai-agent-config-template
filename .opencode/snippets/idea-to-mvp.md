# idea-to-mvp

Use this workflow when a user starts from a product idea. This pipeline does NOT include implementation -- it stops after planning and design.

The Orchestrator dispatches each stage via the Task tool.

## Stages

### Stage 1: repo-explorer

- **Dispatch**: Pass the idea description and any existing system context
- **Output file**: `specs/exploration/repo-exploration.md`
- **Expect back**: Summary of existing repository or system constraints

### Stage 2: requirement-analyst

- **Dispatch**: Pass repo-explorer summary + user's idea description
- **Read upstream**: `specs/exploration/repo-exploration.md`
- **Output file**: `specs/requirements/requirements.md`
- **Expect back**: Summary of goals, users, MVP scope, non-goals, open questions

### Stage 3: task-planner

- **Dispatch**: Pass requirement-analyst summary + user decisions on open questions
- **Read upstream**: `specs/requirements/requirements.md`
- **Output files**: `specs/task-plan/task-plan.md`, `specs/phases/<phase-id>/phase-spec.md`
- **Expect back**: Summary of modules, vertical slices, recommended build order

### Stage 4: solution-architect

- **Dispatch**: Pass task-planner summary + recommended first slice
- **Read upstream**: `specs/requirements/requirements.md`, `specs/phases/<phase-id>/phase-spec.md`
- **Output files**: `specs/phases/<phase-id>/slices/<sub-spec-id>/sub-spec.md`, `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md`
- **Expect back**: Summary of proposed technical design for the MVP

### Stage 5: knowledge-manager

- **Dispatch**: Pass requirement + architecture summaries
- **Action**: Save requirement and architecture milestones as Topic Doc and Decision Doc
- **Expect back**: Confirmation of sync

### Human Gate (final presentation)

- **Present**: Complete idea analysis: requirement summary, module breakdown, technical approach, key risks
- **Purpose**: User reviews the idea analysis. No auto-implementation.
- **Next steps**: User can choose to start `/feature` or `/fullflow` to proceed to implementation

## Expected Outputs

- `specs/exploration/repo-exploration.md` - Repository/system context
- `specs/requirements/requirements.md` - Requirement definition
- `specs/task-plan/task-plan.md` - MVP task plan
- `specs/phases/<phase-id>/slices/<sub-spec-id>/solution-design.md` - Solution design
- Knowledge base records (Topic Doc, Decision Doc)
