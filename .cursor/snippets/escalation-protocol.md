# Escalation Protocol

<!--
  This snippet defines the unified escalation framework for ALL Cursor agents and the Cursor Agent (Orchestrator).
  
  Purpose: When an agent encounters uncertainty, conflict, or a decision it cannot make alone,
  it MUST follow this protocol instead of guessing, assuming, or silently proceeding.
  
  This snippet is referenced by:
  - Every agent definition (Stop & Escalate Conditions section)
  - AGENTS.md (Global escalation rules)
  - feature.md / bugfix.md / implement.md (Phase-level escalation awareness)
-->

## Core Principle

**When in doubt, STOP. Do NOT guess.**

An agent's job is to produce correct, traceable output within its defined scope. When it cannot do this with confidence, escalation is not a failure — it is the correct behavior. Guessing is the failure.

---

## Escalation Level Taxonomy

Every escalation MUST carry one of these four levels. The level determines what the Cursor Agent does with it.

| Level | Name | Meaning | Cursor Agent Response |
|:-----:|------|---------|----------------------|
| 🟢 | **FYI** | "Here's something you should know. I'm continuing." | Read, record in current-status.json, continue pipeline |
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
- `requirements.md` says Phase 3 implements Module M07, but `phase-plan.md` assigns M07 to Phase 5.
- Existing code in the repository implements behavior X, but the sub-spec requires behavior Y for the same interface.

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

## Stop & Explore（与 Stop & Escalate 并列的一条独立通路）

**核心区分**：

| | `Stop & Escalate` | `Stop & Explore` |
|---|---|---|
| 场景 | 我查不出来 / 查出来也不该我决定 | **我能查到，但我现在还没查** |
| 动作 | 交出去（用户 / 上游） | **停下来先查**，查完**自己做** |
| 占用 escalation 通道？ | 是（🟡/🔴/⚫） | **否** —— 不产生级别、不需要用户决策 |
| 谁执行 | 用户或上游 agent | 调度者派 `code-explorer`，然后**续做**原 agent |

**为什么需要它**：Trigger C（Uncertainty Beyond Threshold）的判据是
「missing information **cannot be reasonably inferred**」。而设计阶段最常缺的信息
（"现有模块怎么做的"）**是能查到的，只是没查**。若无这条通路，agent 只剩两个选择：
**猜**，或**为一件本该自己查的事去打扰用户** —— 两者都是失败。

### 触发信号（任一命中即触发）

| # | 信号 |
|:--:|---|
| 1 | 要引用任何现有**文件 / 函数 / 接口 / 配置项**，但尚未证实其存在与形态 |
| 2 | 出现「复用现有的 X」「扩展现有的 Y」「沿用当前的 Z」 |
| 3 | 做**选型决策**（「用 A 而不是 B」）却不知道 A/B 在仓库中的现状 |
| 4 | 需要遵循「**现有约定**」（命名 / 错误处理 / 测试方式 / 目录结构） |
| 5 | 上游文档（需求 / ui-spec）假定某行为或组件**已经存在** |
| 6 | 自检时出现「应该」「大概」「通常」「推测」「按惯例」 |

**判据一句话**：**若你无法为某条断言给出 `路径:行号`，那它就还没有资格成为结论。**

### 输出格式（以此**代替**正常输出）

```markdown
## ⏸ STOP & EXPLORE — 需要代码调研

**From:** `<agent-name>`
**待确认项：** N 条

### 我卡在哪里

<为什么这些事实不能靠推断得到；它们分别影响哪项决策>

### 需要确认的事实（全部列出，编号）

| # | 需要确认的事实 | 为什么影响决策 | 建议查证位置 |
|:--:|---|---|---|
| 1 | <事实> | <影响> | <目录/文件/关键词> |

### 建议的调研范围

<具体目录 / 文件 / 关键词，帮 code-explorer 聚焦，避免全仓库扫描>
```

### 🔴 两条铁律

1. **批量收集后再返回**：收集完**全部**待确认项，一次性返回。逐个返回会让
   一次设计产生多次「agent → 调度者 → explorer → 续做」往返，机制会因太贵而被绕过。
2. **不得用 `Stop & Explore` 替代 `Stop & Escalate`**：查完之后若结论是
   「需求与现状冲突，必须改需求」——那是 Trigger B，走 escalation，不是"查完自己改需求"。

### 调度者的响应

```
1. 收到 STOP & EXPLORE（不是 escalation，不触发用户决策）
2. 派发 code-explorer（workflow 模式 → repo-exploration.md）
3. 续做原 agent（不重新开始、不归档其产物），附上报告路径
4. 原 agent 把查实的事实落进产物（如 design.md 的「现状依据」章节）后继续
```

**不涉及任何 Human Gate** —— 它在 HG-1 之后、HG-2 之前自然发生，用户仍在 HG-2 做方案确认。

---

## Escalation Output Format

When an agent escalates, it MUST produce output in this format INSTEAD OF its normal output:

```markdown
## ⚠️ ESCALATION — <Level>

**From:** `<agent-name>`
**Phase:** `<phase-id>`
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

### Source Authority Hierarchy

When two authoritative sources conflict, the higher-authority source wins:

| Priority | Source | Overrides |
|:--------:|--------|-----------|
| 1 (highest) | Original design document (user-provided) | Everything below |
| 2 | User verbal/written confirmation during pipeline | requirements.md, design.md |
| 3 | `.specdev/specs/<slug>/requirements.md` | design.md, phase-spec.md |
| 4 | `.specdev/specs/<slug>/design.md` | phase-spec.md |
| 5 | `.specdev/specs/<slug>/phases/<phase>/spec.md` | Nothing (implementation-level detail) |

### Agent Authority Hierarchy

When two agents disagree on a factual matter (not a design decision):

| Priority | Agent | Domain |
|:--------:|-------|--------|
| 1 | `code-explorer` | Repository reality (what code actually exists) |
| 2 | `requirement-analyst` | Requirements interpretation |
| 3 | `plan-generator` | Phase/architecture assignment |
| 4 | `reviewer` / `reviewer-correctness` | Code correctness relative to design |
| 5 | `reviewer-design` | Design consistency |
| 6 | `reviewer-connectivity` | Integration connectivity |
| 7 | `verifier` | Empirical test results |

**Exception:** If a lower-authority agent presents empirical evidence (e.g., verifier shows the code actually fails) that contradicts a higher-authority agent's claim, the empirical evidence takes precedence.

**NEVER default to "the agent that ran later wins."**

---

## Escalation Response Protocol (Cursor Agent)

When an agent returns an escalation instead of normal output:

### 🟢 FYI
1. Read the escalation
2. Record in `current-status.json` escalation log
3. Continue to next stage

### 🟡 DECISION
1. STOP the pipeline immediately
2. Present the escalation to the user with the Human Gate format
3. Add "Your decision required before I can continue" header
4. Record the user's decision in `current-status.json`
5. Re-dispatch the SAME agent with the decision as additional context
6. The agent resumes from where it stopped

### 🔴 BLOCKING
1. STOP the pipeline immediately
2. Present the escalation to the user
3. User chooses: (a) provide missing information → re-dispatch same agent, (b) modify upstream spec → re-dispatch earlier agent, (c) accept constraint → agent works within it, (d) abort
4. Record decision in `current-status.json`

### ⚫ CRITICAL
1. HALT ALL active pipelines — do not dispatch any new agents
2. Present escalation to user IMMEDIATELY with ⚫ CRITICAL header
3. List ALL potentially affected phases/modules
4. User decides whether to continue, re-scope, or abort
5. If user decides to continue: record the decision with rationale
6. If user decides to abort: update all phase statuses, close pipelines

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
