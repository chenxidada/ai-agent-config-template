# bugfix-pipeline

Use this workflow for a debugging and repair task.

1. `repo-explorer` traces the failing path, affected modules, and likely root-cause area
2. `requirement-analyst` reframes the bug in terms of expected vs actual behavior
3. `knowledge-manager` auto-triggers checkpoint sync if a durable root-cause framing is reached
4. `task-planner` defines the smallest safe fix slice
5. `implementer` applies the minimal repair
6. `reviewer` checks whether the fix is narrowly scoped and does not introduce hidden quality issues
7. `validator` runs verification and regression checks
8. `knowledge-manager` auto-triggers debugging or validation checkpoint sync and records root cause, fix, and verification result
