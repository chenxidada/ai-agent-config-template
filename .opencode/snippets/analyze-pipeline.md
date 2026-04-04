# analyze-pipeline

Use this workflow to analyze a codebase or module and produce a human-readable analysis report. The Orchestrator dispatches each stage via the Task tool.

This is a lightweight pipeline (1 analysis stage + 1 KM sync). No Human Gate is needed because this is a read-only analysis operation with no code changes.

## Incremental Analysis Support

This pipeline supports **incremental analysis with compression recovery**. When analyzing large codebases, `code-analyst` may need multiple dispatch cycles to complete the analysis.

### Pre-dispatch Check

Before dispatching `code-analyst`, the Orchestrator MUST:

1. Check if `specs/analysis/.analysis-progress.json` exists
2. If exists and `status` is `in_progress`:
   - This is a **resume** scenario
   - Add `resume: true` to the dispatch prompt
   - Include the progress file path
   - Track resume count in `current-status.md` (max 5 resumes)
3. If not exists or `status` is `completed`:
   - This is a **fresh start**
   - Dispatch normally

### Compression Recovery Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Orchestrator                                  │
│                                                                  │
│  1. Check progress file exists?                                  │
│     ├─ No  → Dispatch code-analyst (fresh)                       │
│     └─ Yes → Check status                                        │
│              ├─ completed → Dispatch fresh (new analysis)        │
│              └─ in_progress → Dispatch with resume: true         │
│                                                                  │
│  2. code-analyst returns                                         │
│     ├─ Normal completion → Stage 2 (knowledge-manager)           │
│     └─ context_pressure → Update current-status.md               │
│                           Wait for compression recovery          │
│                           Re-dispatch with resume: true          │
│                                                                  │
│  3. Max 5 resume cycles. If exceeded → Escalate to user          │
│     with partial results and ask how to proceed                  │
└─────────────────────────────────────────────────────────────────┘
```

## Stages

### Stage 1: code-analyst

- **Pre-check**: Check for existing progress file (see Pre-dispatch Check above)
- **Dispatch**: Pass the user's analysis request, including scope and focus angle (if any)
- **Output file**: `specs/analysis/code-analysis-<scope-slug>.md` (code-analyst determines the appropriate filename based on scope)
- **Progress file**: `specs/analysis/.analysis-progress.json` (maintained by code-analyst)
- **Expect back**: Summary of key findings, output file path, areas of limited analysis, OR context_pressure status

#### Fresh Start Dispatch Prompt

```
You are code-analyst. Analyze the following codebase/module and produce a comprehensive analysis report.

## Analysis Request
Scope: <full repo | specific path | specific angle>
Focus angle: <specific dimension if any, otherwise "comprehensive">
Repository path: <working directory>

## Incremental Mode
For large codebases, use incremental analysis:
1. Create specs/analysis/.analysis-progress.json to track progress
2. Analyze module by module
3. If context pressure is high, save progress and return with status: context_pressure

## Output Instructions
1. Write your complete analysis following the templates/code-analysis-output.md format
   to: specs/analysis/code-analysis-<scope-slug>.md
2. Create the specs/analysis/ directory if it does not exist
3. Maintain progress in specs/analysis/.analysis-progress.json
4. Return to me ONLY:
   - A 3-5 sentence summary of the most important findings
   - The output file path
   - Key observations that may be surprising or important
   - Any areas where the analysis was limited
   OR if context pressure:
   - Status: context_pressure
   - Progress file path
   - Completion percentage
   - What remains to analyze
   Do NOT include the full analysis document in your return message.
```

#### Resume Dispatch Prompt

```
You are code-analyst. Continue the interrupted analysis.

## Resume Instructions
resume: true
Progress file: specs/analysis/.analysis-progress.json

1. Read the progress file to understand current state
2. Read the partial output file if it exists
3. Continue from where you left off (currentModule in progress file)
4. Skip already completed modules
5. Continue appending to partial findings

## Analysis Request (original)
Scope: <original scope>
Focus angle: <original focus angle>
Repository path: <working directory>

## Output Instructions
Same as fresh start - write to output file, maintain progress file, return summary or context_pressure status.
```

### Stage 1.5: Compression Recovery Loop (Orchestrator internal)

This is not a separate agent dispatch, but Orchestrator behavior:

1. If `code-analyst` returns `context_pressure`:
   - Log the partial completion status
   - Update `current-status.md` with resume tracking
   - Wait for context compression to complete
   - After compression recovery, re-dispatch `code-analyst` with resume prompt
2. Track resume count:
   - Record in `current-status.md` Loop Tracking: `code-analyst resume 2/5`
3. If resume count exceeds 5:
   - Escalate to user with partial results
   - Present options: continue with another 5 cycles, accept partial results, or abort

### Stage 2: knowledge-manager (analysis checkpoint)

- **Dispatch**: Pass code-analyst summary + output file path
- **Action**: Sync analysis result as Topic Doc to knowledge base
  - Folder: `Projects/<project>/Topics/`
  - Title format: `[topic:code-analysis] <project> - <scope description>`
  - If a Topic Doc for this scope already exists, update it; otherwise create new
- **Expect back**: Confirmation of sync

### Completion

After knowledge-manager sync:

1. Update `specs/current-status.md` to mark pipeline complete
2. Clean up progress file: delete `specs/analysis/.analysis-progress.json` or leave for reference
3. Present to the user:
   - The analysis summary from code-analyst
   - The full report file path (so they can read the complete analysis)
   - KB sync status
   - If analysis required multiple resume cycles, note this
