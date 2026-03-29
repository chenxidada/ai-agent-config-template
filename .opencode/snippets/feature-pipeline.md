# feature-pipeline

Use this workflow for a new feature implementation.

1. `repo-explorer` maps the relevant code paths, modules, and likely impact surface
2. `requirement-analyst` clarifies the feature intent and acceptance criteria
3. `knowledge-manager` auto-triggers requirement checkpoint sync
4. `task-planner` slices the feature into a small delivery unit
5. `solution-architect` defines the technical approach if needed
6. `knowledge-manager` auto-triggers planning or architecture checkpoint sync when a durable design conclusion is reached
7. `implementer` builds the approved slice only
8. `reviewer` checks for scope drift, maintainability issues, and hidden risk
9. `validator` verifies functional behavior, regression risk, and acceptance criteria
10. `knowledge-manager` auto-triggers implementation or validation checkpoint sync and saves the result
