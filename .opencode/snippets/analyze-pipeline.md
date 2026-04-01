# analyze-pipeline

Use this workflow to analyze a codebase or module and produce a human-readable analysis report. The Orchestrator dispatches each stage via the Task tool.

This is a lightweight pipeline (1 analysis stage + 1 KM sync). No Human Gate is needed because this is a read-only analysis operation with no code changes.

## Stages

### Stage 1: code-analyst

- **Dispatch**: Pass the user's analysis request, including scope and focus angle (if any)
- **Output file**: `specs/analysis/code-analysis-<scope-slug>.md` (code-analyst determines the appropriate filename based on scope)
- **Expect back**: Summary of key findings, output file path, areas of limited analysis

Example dispatch prompt:

```
You are code-analyst. Analyze the following codebase/module and produce a comprehensive analysis report.

## Analysis Request
Scope: <full repo | specific path | specific angle>
Focus angle: <specific dimension if any, otherwise "comprehensive">
Repository path: <working directory>

## Output Instructions
1. Write your complete analysis following the templates/code-analysis-output.md format
   to: specs/analysis/code-analysis-<scope-slug>.md
2. Create the specs/analysis/ directory if it does not exist
3. Return to me ONLY:
   - A 3-5 sentence summary of the most important findings
   - The output file path
   - Key observations that may be surprising or important
   - Any areas where the analysis was limited
   Do NOT include the full analysis document in your return message.
```

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
2. Present to the user:
   - The analysis summary from code-analyst
   - The full report file path (so they can read the complete analysis)
   - KB sync status
