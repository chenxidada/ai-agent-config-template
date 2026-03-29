# .opencode Template Convention

This directory is the shared OpenCode template root.

Recommended layout:

- `skills/` - reusable OpenCode skills
- `agents/` - reusable role definitions for staged workflows
- `templates/` - reusable prompt or output templates
- `hooks/` - optional automation scripts or hook docs
- `snippets/` - small reusable task snippets

Current recommended staged agents:

- `repo-explorer`
- `requirement-analyst`
- `program-planner`
- `task-planner`
- `solution-architect`
- `implementer`
- `reviewer`
- `validator`
- `knowledge-manager`

Recommended use:

- Use `agents/` to define role boundaries
- Use `snippets/` to define multi-agent workflows
- Use `templates/` to standardize outputs across stages
- See `AGENT_ROLE_MATRIX.md` for the consolidated role map
- See `AGENT_TRIGGER_MATRIX.md` for when to use the full flow vs a shorter path
- See `snippets/kb-sync-sop.md` for the required MCP sync procedure
- See `hooks/kb-sync-runtime-plugin.md` for the OpenCode runtime trigger implementation

Recommended master workflow:

- `snippets/requirements-to-implementation-workflow.md`

Guidelines:

- Keep this directory generic and reusable across projects
- Put knowledge-base related defaults here first
- Do not hardcode machine-specific absolute paths in files here
- If a file depends on local paths, resolve them through env vars or launcher scripts
- When adding new content here, distribute it via `setup.sh`

Knowledge sync model:

- prefer structured knowledge objects over one monolithic project note
- use `Tasks`, `Topics`, `Decisions`, and `Snapshots` under `Projects/<project>/`
- use `Daily/<YYYY>/<YYYY-MM>/` for day-based continuity notes
- allow one workflow checkpoint to write more than one object when that improves retrieval
- treat sync as a real runtime action, not just a documentation reminder

Trigger model:

- automatic compression trigger -> create `Snapshot Doc` and update `Daily Digest`
- automatic workflow checkpoint trigger -> sync the completed stage result immediately
- manual user trigger -> summarize and sync on explicit request

Runtime expectation:

- a trigger is only fulfilled if MCP write actions actually ran
- workflow stages are not fully complete until their required checkpoint sync finishes
- future hooks or orchestrators should call the same MCP-first sync flow defined in `snippets/kb-sync-sop.md`
- the default OpenCode runtime plugin is configured in `opencode.jsonc` and implemented in `.opencode/plugins/kb-sync-runtime.mjs`

Spec sync model:

- sync `master-spec` to `Projects/<project>/Specs/Master`
- sync `phase-spec` to `Projects/<project>/Specs/Phases`
- sync `sub-spec` to `Projects/<project>/Specs/SubSpecs`
- sync `current-status` to `Projects/<project>/Specs/Status`
- treat `master-spec` as the primary planning artifact for large projects

Recommended specs layout in repositories:

- `specs/master-spec.md`
- `specs/current-status.md`
- `specs/phases/<phase-id>/phase-spec.md`
- `specs/phases/<phase-id>/slices/<sub-spec-id>.md`
- legacy flat layouts can still be read during migration, but new projects should prefer the nested `phases/<phase-id>/slices/` layout
