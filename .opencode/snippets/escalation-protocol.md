# Escalation Protocol

<!--
  This snippet defines the unified escalation framework for ALL agents and the Orchestrator.
  
  Purpose: When an agent encounters uncertainty, conflict, or a decision it cannot make alone,
  it MUST follow this protocol instead of guessing, assuming, or silently proceeding.
  
  This snippet is referenced by:
  - Every agent definition (Stop & Escalate Conditions section)
  - orchestrator.md (Escalation Handling Protocol)
  - AGENTS.md (Global escalation rules)
  - unified-pipeline.md (Stage-level escalation awareness)
-->

## Core Principle

**When in doubt, STOP. Do NOT guess.**

An agent's job is to produce correct, traceable output within its defined scope. When it cannot do this with confidence, escalation is not a failure — it is the correct behavior. Guessing is the failure.

---

## Escalation Level Taxonomy

Every escalation MUST carry one of these four levels. The level determines what the Orchestrator does with it.

| Level | Name | Meaning | Orchestrator Response |
|:-----:|------|---------|----------------------|
| 🟢 | **FYI** | "Here's something you should know. I'm continuing." | Read, record in current-status.md, continue pipeline |
| 🟡 | **DECISION** | "I cannot proceed until you choose between options A, B, or C." | Stop pipeline, present to user, wait for decision |
| 🔴 | **BLOCKING** | "I've hit an obstacle I cannot resolve within my role. My work is paused." | Stop pipeline, present to user, determine next action (re-dispatch, re-scope, abort) |
| ⚫ | **CRITICAL** | "Stop everything. This affects completed/ongoing work in other phases or threatens system integrity." | Halt ALL active pipelines, present to user immediately, do NOT proceed with any work until resolved |

---

## When to Escalate: Stop Condition Triggers

An agent MUST escalate (not guess, not assume, not work around) when:

### A. Decision Required（需要人类决策）

The agent faces a choice between multiple VALID approaches, and the choice has downstream consequences beyond the agent's authority.

**Examples:**
- "I can implement this with approach A (simpler, slower) or approach B (complex, faster). Trade-off: A takes 2 days more but is more maintainable."
- "Phase 2 and Phase 3 both need Module X. Should X be frozen in Phase 2, or left extensible until Phase 3?"
- "The design document doesn't specify the error handling strategy for this scenario. Options: crash, retry, or degrade."

**Rule:** If the agent can think of ≥2 valid approaches and the choice affects other modules/phases → DECISION escalation.

### B. Conflict Detected（发现冲突）

The agent discovers that two authoritative sources disagree.

**Examples:**
- Design document says `sizeof(X) == 32`, but the struct definition in the design doc has fields that sum to 40.
- `requirements.md` says Phase 3 implements Module M07, but `master-spec.md` assigns M07 to Phase 5.
- Existing code in the repository implements behavior X, but the sub-spec requires behavior Y for the same interface.
- Two module contracts define incompatible interfaces for the same interaction.

**Rule:** If the conflict is between sources of equal or higher authority than the agent → BLOCKING escalation. The agent MUST cite both sources with exact quotes.

### C. Uncertainty Beyond Threshold（不确定超出阈值）

The agent lacks information needed to produce correct output, and the missing information cannot be reasonably inferred.

**Examples:**
- "The requirements say 'high performance' but give no quantitative target. I need a latency number to design the data path."
- "The phase-assignment lists Module M05 for this phase, but I cannot find M05's interface definition anywhere in the design doc or requirements."
- "The existing code uses pattern X extensively. The sub-spec says to use pattern Y. I don't know whether to follow the existing pattern or the spec."

**Rule:** If the agent estimates confidence < 80% on a decision that affects correctness → DECISION escalation. The agent MUST state what information is missing and why it matters.

### D. Impossible Within Constraints（在约束下不可行）

The agent determines that what's being asked is logically or physically impossible given the constraints.

**Examples:**
- "The sub-spec requires `sizeof(Message) <= 16` but the required fields (5 × uint64 = 40 bytes) cannot fit."
- "Phase 3 requires Module X but Module X depends on Module Y which won't exist until Phase 7."
- "The deadline is 3 phases in 1 week, but each phase requires at least 2 sub-specs with review cycles."

**Rule:** BLOCKING escalation. The agent MUST explain the constraint violation with concrete numbers.

---

## Escalation Output Format

When an agent escalates, it MUST produce output in this format INSTEAD OF its normal output:

```markdown
## ⚠️ ESCALATION — <Level>

**From:** `<agent-name>`
**Phase/Slice:** `<phase-id or sub-spec-id>`
**Level:** 🟢 FYI / 🟡 DECISION / 🔴 BLOCKING / ⚫ CRITICAL

### What Stopped Me

<Concrete description of what the agent encountered. Include exact quotes from source documents, file paths, and line numbers.>

### What I Was Trying To Do

<The task the agent was working on when it hit the stop condition.>

### Why I Can't Proceed

<Why this cannot be resolved autonomously. Reference the specific Stop Condition Trigger (A/B/C/D) from the escalation protocol.>

### What I Need From You

<Specific question(s) for the human. If DECISION level: list options A, B, C with trade-offs. If BLOCKING: state what must change. If CRITICAL: state the scope of impact.>

### My Recommendation (Optional)

<If the agent has a recommendation, state it clearly and explain the reasoning. Mark clearly as RECOMMENDATION, not decision.>
```

---

## Conflict Resolution Rules

When the Orchestrator receives a BLOCKING escalation due to conflict, these precedence rules apply:

### Source Authority Hierarchy

When two authoritative sources conflict, the higher-authority source wins:

| Priority | Source | Overrides |
|:--------:|--------|-----------|
| 1 (highest) | Original design document (user-provided) | Everything below |
| 2 | User verbal/written confirmation during pipeline | requirements.md, master-spec.md |
| 3 | `specs/requirements/requirements.md` | master-spec.md, phase-spec.md, sub-spec.md |
| 4 | `specs/master-spec.md` | phase-spec.md, sub-spec.md |
| 5 | `specs/phases/<phase-id>/requirements.md` | phase-spec.md, sub-spec.md |
| 6 | `specs/phases/<phase-id>/phase-spec.md` | sub-spec.md |
| 7 (lowest) | `specs/phases/<phase-id>/slices/<id>/sub-spec.md` | Nothing (implementation-level detail) |

### Agent Authority Hierarchy

When two agents disagree on a factual matter (not a design decision):

| Priority | Agent | Domain |
|:--------:|-------|--------|
| 1 | `repo-explorer` | Repository reality (what code actually exists) |
| 2 | `requirement-analyst` | Requirements interpretation |
| 3 | `program-planner` | Phase/module assignment |
| 4 | `solution-architect` | Technical design approach |
| 5 | `reviewer` | Code correctness relative to design |
| 6 | `validator` | Empirical test results |

**Exception:** If a lower-authority agent presents empirical evidence (e.g., validator shows the code actually fails) that contradicts a higher-authority agent's claim, the empirical evidence takes precedence.

### Cross-Agent Conflict Resolution

When agent A and agent B disagree on a matter within both their domains:

1. Orchestrator reads BOTH agents' full output files
2. Orchestrator identifies the specific point of disagreement (exact claim, not summary)
3. Orchestrator checks the Source Authority Hierarchy
4. If the hierarchy resolves it → apply the higher source's position
5. If the hierarchy does NOT resolve it → 🔴 BLOCKING escalation to user with both positions presented
6. **Never default to "agent A wins because it ran later"** — that's implicit bias

---

## Escalation Response Protocol (Orchestrator)

When an agent returns an escalation instead of normal output:

### 🟢 FYI
1. Read the escalation
2. Record in `specs/current-status.md` §Escalation Log
3. Continue to next stage

### 🟡 DECISION
1. STOP the pipeline immediately
2. Present the escalation to the user with the Human Gate format
3. Add "Your decision required before I can continue" header
4. Record the user's decision in `specs/current-status.md` §User Decisions
5. Re-dispatch the SAME agent with the decision as additional context
6. The agent resumes from where it stopped

### 🔴 BLOCKING
1. STOP the pipeline immediately
2. Present the escalation to the user
3. User chooses: (a) provide missing information → re-dispatch same agent, (b) modify upstream spec → re-dispatch earlier agent, (c) accept constraint → agent works within it, (d) abort
4. Record decision in `specs/current-status.md` §User Decisions

### ⚫ CRITICAL
1. HALT ALL active pipelines — do not dispatch any new agents
2. Present escalation to user IMMEDIATELY with ⚫ CRITICAL header
3. List ALL potentially affected phases/modules
4. User decides whether to continue, re-scope, or abort
5. If user decides to continue: record the decision with rationale
6. If user decides to abort: update all phase statuses, close pipelines

---

## Recording Escalation Outcomes

All escalation outcomes MUST be recorded in:
- `specs/current-status.md` §Escalation Log — timestamp, level, agent, summary, resolution
- The relevant agent's output file — as a `## Escalation Record` section (append mode if the agent is re-dispatched)

---

## Anti-Patterns: What Agents MUST NOT Do

| Anti-Pattern | Why It's Wrong | Correct Behavior |
|-------------|----------------|------------------|
| "I'll assume X for now and note it as an assumption" | Assumptions that affect correctness must be confirmed, not assumed | Escalate: "I need confirmation: is X true or Y true?" |
| "I found a conflict but I'll go with the more recent document" | Temporal order ≠ authority. The newer doc might be wrong. | Escalate: "Source A says X, Source B says Y. Which is correct?" |
| "This is probably what the user meant" | LLMs cannot read minds. Probable ≠ correct. | Escalate: "I interpret this as meaning X. Is that correct?" |
| "I'll implement both approaches and let the reviewer decide" | Wastes implementation effort on wrong approach | Escalate BEFORE implementing |
| "The spec is wrong, so I'll fix it" | Agents have NO authority to modify upstream specs | Escalate: "The spec has an error. Should I use what the spec says or what I think is correct?" |
| "I'll just skip this part and come back to it later" | Creates invisible gaps that compound across phases | Escalate or register as Known Gap with explicit scope |
