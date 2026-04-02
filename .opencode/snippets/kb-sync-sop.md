# KB Sync SOP

## Purpose

Use this SOP when an agent needs to save durable knowledge into the personal knowledge base through `knowledge-base` MCP.

Default language rule:

- write synced summaries, knowledge notes, handoff snapshots, and daily continuity content in Chinese unless the user explicitly requests another language

This SOP assumes:

- knowledge-base MCP is the only official sync path
- structured objects should use the structured object sync entry
- compression events should create a Snapshot Doc and update a Daily Digest

## Trigger Sources

This SOP should run when any of these trigger sources fire:

- automatic compression trigger: compression / reset / handoff
- automatic workflow checkpoint trigger: requirement, decision, milestone, validation, debugging conclusion
- manual user trigger: explicit summarize-and-sync request

If no real sync action is executed, the trigger is not considered fulfilled.

## Step 1: Classify the knowledge

Choose the best-fitting object type first:

- Task Doc for one concrete task or workflow run
- Topic Doc for one recurring theme
- Decision Doc for one important conclusion
- Snapshot Doc for one compression / reset / handoff event
- Daily Digest for same-day continuity and navigation

If more than one view is useful, write more than one object.

## Step 2: Compute the stable key and title

Use the standard naming rules:

- `Task Doc`: `[task:<task-id>] <project> - <task-name>`
- `Topic Doc`: `[topic:<topic-key>] <project> - <topic-name>`
- `Decision Doc`: `[decision:<decision-key>] <project> - <decision-name>`
- `Snapshot Doc`: `[snapshot:YYYYMMDD-HHmmss] <project> - <label>`
- `Daily Digest`: `[daily] YYYY-MM-DD - <project>`

## Step 3: Resolve the target folder by logical path

Never resolve folders by a single ambiguous display name.

### Project Identity Rule

**CRITICAL: Always read `.opencode/project-config.md` first to get the canonical project identifier.**

The project identifier must be consistent across all sync operations. Never:

- Invent a new project name
- Use variations like `ai-agent-template` vs `ai-agent-config-template`
- Use display names instead of the canonical identifier

### Canonical Paths

Use these logical paths with the project identifier from `project-config.md`:

- `Projects/<project>/Tasks/`
- `Projects/<project>/Topics/`
- `Projects/<project>/Decisions/`
- `Projects/<project>/Snapshots/`
- `Daily/<YYYY>/<YYYY-MM>/`

Use the path resolver tool to resolve the path step by step.

## Step 4: Decide create vs update

Create-only object:

- Snapshot Doc

Updateable objects:

- Task Doc
- Topic Doc
- Decision Doc
- Daily Digest

For updateable objects, use the object status query tool or object metadata search first.

## Step 5: Read before merge

If the target updateable document already exists:

1. read the existing document
2. extract only the new high-value information
3. merge incrementally
4. preserve unrelated existing sections

Never overwrite an existing task, topic, decision, or daily document without reading it first.

## Step 6: Write with the right tool

Preferred write tools:

- structured object sync for structured knowledge objects
- runtime event sync for compression, checkpoint, and manual runtime triggers

## Step 7: Use the standard content structure

Recommended structure:

- Metadata: `objectType`, `objectKey`, `project`, `trigger`, `sourceType`, `sourceTool`, `updatedAt`
- Objective
- Key decisions
- Important discoveries
- Implementation status
- Validation status
- Relevant files / commands
- Related documents / links
- Outstanding issues
- Next actions

Language recommendation:

- headings may follow the project convention
- the actual synced explanatory content should default to Chinese
- follow `templates/kb-rendering-guideline.md` so synced content reads naturally in the current frontend markdown renderer

## Step 8: Compression / reset / handoff flow

When the trigger is compression, reset, or handoff:

1. create a new Snapshot Doc
2. resolve today's Daily Digest
3. if daily exists, read and merge
4. if daily does not exist, create it
5. add links between the daily note and the new snapshot when possible
6. if a durable conclusion was reached, also update a Decision Doc or Topic Doc

## Step 8A: Workflow checkpoint flow

When the trigger is a workflow checkpoint:

1. identify which checkpoint was just completed
2. extract only the new high-value result from that stage
3. choose the matching object type
4. if the object is updateable, read before merge
5. execute the structured object sync entry

Example mapping:

- requirement checkpoint -> Topic Doc or Decision Doc
- architecture checkpoint -> Decision Doc
- implementation checkpoint -> Task Doc
- validation checkpoint -> Task Doc
- debugging checkpoint -> Task Doc or Topic Doc

## Step 8B: Manual user-request flow

When the user explicitly asks to summarize and sync:

1. treat the request as an immediate sync task
2. refine the content into durable knowledge
3. choose the best object type instead of defaulting to daily
4. execute the proper high-level sync entry

## Step 9: Quality bar

Only sync high-value information:

- decisions and rationale
- milestones
- blockers
- validation outcome
- next actions
- important discoveries worth reusing later

Avoid:

- raw logs
- repetitive chatter
- full command output unless future work depends on it
- mixing unrelated topics into one document

## Step 10: Failure handling

If a sync attempt fails:

1. retry once
2. if it still fails, report the failure clearly
3. include which object failed, which step failed, and what remains unsynced
