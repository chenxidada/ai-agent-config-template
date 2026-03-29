# rebuild-knownbase-flow

Use this workflow when rebuilding, replicating, or iterating a knowledge-base product like Knownbase.

1. `repo-explorer` inspects the current codebase, subsystem boundaries, and risky integration points first
2. `requirement-analyst` reads the feature or product requirement doc and extracts the true MVP
3. `task-planner` maps the system into vertical slices such as documents, folders/tags, search, AI chat, RAG, PDF, sync, and MCP
4. `solution-architect` proposes the architecture and highlights risky subsystems first
5. `knowledge-manager` saves requirement and architecture milestones immediately
6. `implementer` works slice by slice
7. `reviewer` checks each slice for design drift, maintainability, and hidden coupling
8. `validator` checks each slice before the next starts
9. `knowledge-manager` keeps syncing key lessons so the rebuild itself becomes documented knowledge
