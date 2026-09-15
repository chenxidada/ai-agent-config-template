# Cursor Hooks v8 变更说明（含 Trae 同步指引）

> 状态：**Cursor 侧已完成并自测通过**（**142 项断言全绿**）；**Trae 侧尚未同步**（按用户决策延后）。
>
> ⚠️ **净变化 —— 口径不同结论相反，必须并列给出（这是本节最容易踩的坑）**：
>
> 本轮两次踩到「数字会漂」：先是我编辑文件让它从 `+2780` 变到 `+2792`；
> 接着我把一条**只钉住起点**（终点写 `HEAD`）的命令标成了「稳定值」——
> 提交后 `HEAD` 一移动，那个数字立刻作废。**故铁律是：两端都钉死，或别标「稳定」。**
>
> · **基线（引用这个，两端钉死 → 永不漂移）**：
> `git diff --shortstat 6084ab9 85fe00f -- . ':(exclude).cursor/hooks/CHANGELOG.md'`
> ＝ **40 文件 `+2792 / −2087`**。按状态拆解（同口径实测，勿手算，已验证可复现）：
> 新增 7 文件 `+1022`（`tools/test-*.sh`、`drift-reminder.sh` +137、`emit.sh` +52）
> ／删除 4 文件 `−961`（`pipeline-advance.sh` −363、`ORCHESTRATOR_ARCHITECTURE.md` −432、
> `templates/validation-report.md` −92、`opencode.jsonc` −74）／修改 29 文件 `+1770 / −1126`。
> · **含本文件**：同上命令去掉 `-- . ':(exclude)...'` → **41 文件 `+3672 / −2087`**
> （多出的 `+880` 就是本文件自己）。
> · **只看 v8.4 那一笔**：`git show --shortstat 85fe00f` ＝ 15 文件 `+977 / −88`。
> · **另一个维度**：hooks 层（排除本文件）＝ 8 文件 `+1048 / −966`，**净增 82 行**
> —— `gate` 本体因 v8.4 新增校验而变大（安全机制变强必然如此），减的是别处的死代码。
>
> **`+1233 / −1882`、`净减 649`、`净减 239`、`砍掉 312 行` 四处旧说法全部作废**（溯源见 §11.6）。
> 唯一稳定的定性表述：**减掉的是死代码 961 行（4 个文件），换来的是测试（5 套件 / 142 断言）+ 更强的门禁。**
>
> 本文件含 **§6 勘误**（首轮 5 条断言被证伪）/ **§8 v8.2**（四项决策落地 + 复核发现）/ **§9 v8.3**（平台范围收敛 + 文档清理）
> / **§10**（`drift-reminder.sh` 从未生效）/ **§11**（模板 skill 还原：把发给下游的文件当成了记事本）
> / **§12 v8.4**（设计前探查：把「不许猜」变成可验收的形式）。
> 变更动机：门禁的失败模式不是「拦不住」，而是**「假装在拦」** —— 空操作、静默放行、协议错误。

---

## 0. TL;DR

| # | 问题（v7） | 后果 | 处置 |
|---|---|---|---|
| 1 | `permission:"ask"` 用在 `preToolUse` | 官方文档明确该字段**被接受但不执行** = allow | hg3 三处 `ask` → `deny` |
| 2 | 11 处「读不出来就放行」 | 门禁可被「删文件 / 写坏 JSON / 拼错名字」关闭 | 全部改走 `gate_unknown()` → deny |
| 3 | `subagentStop` 推进 hook 依赖不存在的字段 | 从未生效，纯死代码 | **删除** `pipeline-advance.sh` |
| 4 | 26 处手写 JSON 字面量 | 消息含引号即产出非法 JSON，而 hook 是 `failClosed` → 黑盒崩溃 | 收敛到 `lib/emit.sh` |
| 5 | 判决解析有 3 条绕过路径 | MUST-FIX 可被静默放行 | 严格单值解析 + 证据计数 |
| 6 | 心跳机制 | 只在 allow 上附提醒、永不阻断 + 全局 `/tmp` 污染 | **删除** |

一句话：**把「看起来有保护」改成「真的有保护」—— 净删 961 行死代码 / 废弃配置（4 个文件），同时把 11 处静默放行改成显式拒绝。**
（hooks 层本身 `+937 / −966` → 净减 29 行，口径与重跑命令见顶部。早期「砍掉 312 行」的说法无法复现，已废弃。）

---

## 1. 实测事实（payload 探针确认，双侧通用结论）

> 以下均用临时 `payload-probe.sh` 记录真实 stdin 得到，**不是文档推断**。文档与运行时不一致是这套 hook 最大的坑源。

| # | 事实 | 影响 |
|---|---|---|
| F1 | `preToolUse` 的 `.cwd` 字段**存在但恒为空字符串** | 不能作路径基准 → 改用 `workspace_roots[0]`，退化 `HOOK_DIR/../..` |
| F2 | `StrReplace` 在 `preToolUse` 中上报 `tool_name: "Write"` | 不存在 `Edit` 事件流；`tool_input.content` 是**整个新文件内容**（不是 diff / new_string） |
| F3 | `subagentStop` payload **没有 `agent_name`**（只有 `subagent_type`） | 依赖 `agent_name` 的推进逻辑必然失效 |
| F4 | `subagentStop` 唯一合法输出字段是 `followup_message`（JSON） | 输出纯文本 markdown = 无输出 |
| F5 | `preToolUse` 的 `"ask"` **被 schema 接受但不执行**，等同 `allow` | ⚠️ 比「不支持」更危险 —— 门禁静默失效 |
| F6 | `beforeShellExecution` 的 `"ask"` **真实生效**（弹窗交用户批准） | `shell-guard.sh` 可以、也应当用 `ask` |

**推论（贯穿本次改造的原则）**：
> 「字段被接受但不执行」比「字段不存在」危险一个量级。
> 前者会让代码看起来在工作 —— 于是没人再去检查它。
> **死代码比没有代码更危险。**

---

## 2. Cursor 侧逐文件变更

### 2.1 新增 `.cursor/hooks/lib/emit.sh`（+80）

统一输出原语，替换 gate 内 26 处手写 JSON：

| 函数 | 输出 | 可用事件 |
|---|---|---|
| `emit_allow` | `{permission:"allow"}` | 全部 |
| `emit_allow_msg <msg>` | `+ agent_message` | 全部 |
| `emit_deny <user_msg> [agent_msg]` | `{permission:"deny",...}` | 全部 |
| `emit_ask <user_msg> [agent_msg]` | `{permission:"ask",...}` | **仅 beforeShellExecution / beforeMCPExecution** |

全部经 `jq --arg` 构造（自动转义引号/换行），jq 不可用时降级为最小合法 JSON。
文件头写明**事件 × permission 支持矩阵**，并在 `emit_ask` 上标注「不得在 preToolUse 调用」。

### 2.2 重写 `.cursor/hooks/lib/verdict-parse.sh`（288 行改动）

判决解析收敛为唯一实现 `_parse_verdict_line`，`parse_verdict` / `parse_review_verdict` 是它的两个实例。

**补齐的 3 条绕过路径**（旧实现 → 新实现）：

| 写法 | 旧行为 | 新行为 |
|---|---|---|
| `## 判决：**MUST-FIX** / 需要修复` | 判为「无可解析判决」→ **放行** | `MUST-FIX` ✅ |
| `## 判决结果：MUST-FIX` | 正则要求「判决」后紧跟冒号 → **放行** | `MUST-FIX` ✅ |
| `## 判决：PASS / MUST-FIX / SHOULD-FIX` | 误判为 `PASS` → **放行** | 拒绝（多值枚举）✅ |

归一化策略：剥除全部空白 + markdown 强调符 + 反引号 → 取前导 token → 校验枚举 → **残留第二个判决词即拒绝**。

**新增 `count_blocking_findings`（证据计数）** —— 本次最重要的设计变更：
- 兼容 `## Must-Fix 汇总`（合并报告）与 `### 🔴 Must-Fix`（并行报告）两种区块标题
- 只统计区块内的**列表项 / 表格行**，忽略散文占位（否则空模板会被误计为 1 条）
- 设计意图：**判决是 Agent 可自由书写的字段，🔴 条目是它自己产出的证据。二者矛盾时以证据为准。**

**可移植性**：文件头立下铁律 —— 本库**严禁 `grep -P`**（BSD grep 以退出码 2 失败，而多数用法在 `if !` 中 → 静默反向放行）。全部正则改用 `sed` / `awk` / `grep -E`。

### 2.3 `.cursor/hooks/lib/status-read.sh`

- `LOOP_COUNT` / 新导出 `VERIFIER_LOOP_COUNT` **清洗为纯数字**（`"abc"` → `0`）
  - 原因：`[ "abc" -ge 2 ]` 抛错 → 条件为假 → **熔断静默失效**
  - 清洗收敛在这一处，而非每个调用方各自防御
- 移除对已删除的 `pipeline-advance.sh` 的引用

### 2.4 重写 `.cursor/hooks/pipeline-gate.sh`（830 行改动）

**删除**：心跳机制（`HEARTBEAT_FILE` / `check_heartbeat` / `allow_with_heartbeat`，8 处调用点）。

**新增 `gate_unknown()`** —— fail-closed 的单一出口：

```
活跃工作流期间，「读不出来」是故障，不是放行理由 → deny
无活跃工作流时（日常写代码）门禁本就无关 → allow（不误伤）
```

**修复的 11 处静默放行**：

| 位置 | v7 行为 | v8 |
|---|---|---|
| `read_status` 失败（Edit 路径） | 降级为「全 pending + phase 空」继续 → **hg3 无校验写入** | deny |
| `current_phase` 为空 | hg3 校验整体被 `if [ -n ... ]` 跳过 → **无校验** | deny |
| 写入内容解析失败 | 得到空串 → 全部 `grep -q` 为假 → **校验静默跳过** | deny |
| git 分支读取失败 | `unknown` → 跳过分支校验 | deny |
| DAG JSON 解析失败 | `return 0` → Phase ID 校验关闭 | deny |
| `phase-plan.md` 缺失 | `return 0` | deny |
| 未知子 Agent 名 | **allow** → 拼错名字即可绕过全部 HG | deny |
| `read_phase_ui` 解析失败 | 返回 `false` → UI 门禁全关 | **三态** `true/false/unknown`，unknown → deny |
| `LOOP_COUNT` 非数字 | `-ge` 抛错 → 熔断失效 | 清洗 |
| `verifier_loop_count` 非数字 | 同上 | 清洗 |
| 显式清空 `current_phase` | 回落旧值 → 校验被绕过 | deny（新增检测） |

**裁决判定改为「自陈 + 证据」双判**：`review.md` 自陈 `PASS`，但 Must-Fix 区实测有 🔴 时仍 deny。证据来源包含 **4 份并行 reviewer 原始报告**（防止合并时丢失 MUST-FIX）。

**hg3 三处 `ask` → `deny`**（依据 F5）。

**项目根**改用 `workspace_roots[0]`（依据 F1），并新增 `project_rel()` 让 deny 消息里显示相对路径（可读性）。

**新增 `require_ui_gates()`** 消除 reviewer / verifier 两处重复的三态判定。

### 2.5 `.cursor/hooks/shell-guard.sh`（87 行改动）

引入 `source lib/emit.sh`，并把处置分为三类：

| 处置 | 适用 | 说明 |
|---|---|---|
| `deny` | `rm -rf /`、fork bomb、`git stash` | **无覆盖通道**（stash 会让 Phase 代码丢失） |
| `ask` | 敏感路径、系统根递归修改、全盘扫描、`git commit/push` | 交用户**当场**裁决 |
| `allow` | 其余 | — |

逃生舱标记（`/tmp/command-guard-allowed`、`/tmp/git-commit-allowed`）**保留**，语义从「唯一的覆盖通道」变为「**事先**同意的快速通道」（marker 新鲜 → 直接 allow、不弹窗）。`ask`（当场确认）与 marker（事先确认）互补。

**语义变更提示**：`git commit/push` 从「deny + 要求用户回复『允许提交』+ Agent 手工 touch marker」变为 **弹窗确认**。规范流程（仅在 HG-3 用户确认后提交、显式文件清单、禁止 `git add -A`）在 ask 消息里。

### 2.6 删除 `.cursor/hooks/pipeline-advance.sh`（−363）

删因（两个协议错误叠加，**该脚本从未产生过任何引导**）：
1. 依赖 stdin 的 `agent_name`（依据 F3 —— 该字段不存在）
2. 输出纯文本 markdown，而 `subagentStop` 只认 `followup_message`（依据 F4）

替代：`spec-workflow.mdc`（Always Apply，抗压缩）+ `sessionStart` 的 `emit_anchoring_block`（已按 `current_stage` 分支给出「该做 / 不能做」）。

### 2.7 `.cursor/hooks.json`（−13）

- 删除 `subagentStop` 整块
- 删除 `matcher: "Shell"` 条目 —— 对应 gate 分支是无条件 `allow`，**每个 shell 命令白起一个进程**（纯浪费，`shell-guard.sh` 已覆盖命令安全）
- 保留 `Task` / `Edit` / `Write` 三个条目（`Edit` 当前不触发，但保留作为 Cursor 未来变更的防御）

### 2.8 文档同步

| 文件 | 变更 |
|---|---|
| `.cursor/rules/spec-workflow.mdc` | 3 处 `pipeline-advance` 引用改写；明确「**没有任何 hook 会代你推进**」 |
| `AGENTS.md` | 钩子表更新为 task 实际事件（`beforeShellExecution` / `sessionStart`） |
| `README.md` | 目录树更新（`emit.sh` + `shell-guard.sh`） |
| `.cursor/commands/feature.md` | 「hook 会触发 HG-1 停止」→「**你必须主动停下**」 |

### 2.9 新增测试（`tools/`）

门禁自身此前**从无验证者**。新增三个可重跑的行为测试：

```bash
bash tools/test-verdict.sh       # 21 项
bash tools/test-gate.sh          # 41 项
bash tools/test-shell-guard.sh   # 22 项
bash tools/test-hook-contract.sh # 27 项
bash tools/test-drift.sh         # 22 项
# 合计 133 项（v8.2 实测；旧的 21/30/22/21 数字已作废）
```

`test-gate.sh` 用**真实 hook 输入格式**构造 payload，指向临时沙箱项目，断言 allow/deny，覆盖上表全部 fail-open 点。

---

## 3. Trae 侧同步清单

> ⚠️ **不要直接复制文件**。Trae 与 Cursor 的 hook 协议不同（事件名、matcher 语法、输出格式），
> 下面的「动作」栏区分了**可直接移植**、**需按 Trae 协议改写**、**需先在 Trae 实测**三类。

### 3.1 可直接移植（与协议无关的纯逻辑）

| 目标文件 | 动作 |
|---|---|
| `.trae/hooks/lib/verdict-parse.sh` | **整体替换**为 Cursor 版。这是纯字符串解析，与事件协议无关。同步后跑 `tools/test-verdict.sh`（把 source 路径指向 `.trae`） |
| `.trae/hooks/lib/status-read.sh` | 移植**数字清洗**两段（`LOOP_COUNT` / 新增 `VERIFIER_LOOP_COUNT`）。注意 Trae 版可能已有额外导出，**不要整体覆盖** |
| `.trae/hooks/lib/emit.sh` | **新增**，但需先确认 Trae 的 permission 支持矩阵（见 3.3）。若 Trae 不支持 `ask`，把 `emit_ask` 改为 `deny` |
| `tools/*.sh` | 整体复制，改各脚本内的 `GATE` / `GUARD` 路径变量为 `.trae/hooks/...` |

### 3.2 需按 Trae 协议改写

| 源 | 目标 | 差异点 |
|---|---|---|
| `.cursor/hooks/pipeline-gate.sh` | `.trae/hooks/pipeline-gate.sh` | Trae 的 `matcher: "Write|Edit|RunCommand"` **支持 `\|` 交替**，且把 shell 并入同一 matcher → Trae 版不需要为 Shell 单开条目，但要确认 gate 内是否有 `RunCommand` 分支。Cursor 版删除的「Shell 无条件 allow 分支」在 Trae 版**不能删**（Trae 把 shell 也交给 gate） |
| `.cursor/hooks.json` | `.trae/hooks.json` | 保持 Trae 的 Claude-Code 风格 schema（`PreToolUse` + 嵌套 `hooks[]`），**不要照搬 Cursor 的扁平结构** |

### 3.3 需先在 Trae 实测的事实

| # | 待验问题 | 影响 |
|---|---|---|
| T1 | Trae 的 hook 输入里，项目根字段是什么？（`cwd`? `workspace_roots`?） | 决定门禁用哪个字段定位 `PROJECT_ROOT`。Cursor 的 F1 结论**不自动适用于 Trae** |
| T2 | Trae 的 `PreToolUse` 是否支持 `permission:"ask"`？是否生效？ | 决定 `emit_ask` 在 gate 里是否可用（Cursor 答案：**不生效**） |
| T3 | Trae 编辑文件时上报的 `tool_name` 是什么？`tool_input` 含完整 `content` 还是 diff？ | 决定「写入内容解析失败即 deny」这条路是否可用 |
| T4 | Trae 的 `Stop` 事件语义（`loop_limit: 5`）与 stdout 契约 | **决定 `pipeline-advance.sh` 该不该删** —— 见下 |

### 3.4 ⚠️ 关键差异：Trae 的 `pipeline-advance.sh` 不要照删

Cursor 侧删除该脚本，依据是 **Cursor 的 `subagentStop` payload 没有 `agent_name`、输出只认 `followup_message`**（F3/F4）。

但 Trae 侧它绑定在 **`Stop`** 事件（`.trae/hooks.json:28-44`，且带 `loop_limit: 5`）——
这是 Claude-Code 风格的事件：`Stop` 的 stdout **是给用户看的**，且可用退出码 2 阻断继续。
**F3/F4 对它不成立。**

→ **动作**：先在 Trae 实测 `Stop` 事件（打印 payload + 观察 stdout 是否被消费），再决定删/留/改写。**不要因为 Cursor 删了就跟着删。**

### 3.5 已分叉清单（禁止单向覆盖）

Trae 侧存在 Cursor 侧**完全缺失**的机制，同步时须保护：

| Trae 独有 | 用途 | Cursor 侧状态 |
|---|---|---|
| `.trae/hooks/post-tool-drift.sh` + `lib/drift-lib.sh` | `PostToolUse` 漂移检测 | **缺失** |
| `.trae/hooks/subagent-contract.sh` | `SubagentStop` 契约校验 | **缺失** —— 但 Cursor 侧现已注册 `drift-reminder.sh`（见 §8.2），功能定位部分重叠；Trae 版本做的是**契约校验**，比「漂移提醒」更强，仍值得对照 |
| `.trae/templates/*`（dispatch-prompt / scope-gap-report / sub-spec …） | 派发与范围模板 | **缺失** |

→ **待决**：这三项是否要反向移植到 Cursor 侧？（本轮未做）

---

## 4. 验证结果

```
bash tools/test-verdict.sh        → 21 通过 / 0 失败
bash tools/test-gate.sh           → 41 通过 / 0 失败
bash tools/test-shell-guard.sh    → 22 通过 / 0 失败
bash tools/test-hook-contract.sh  → 27 通过 / 0 失败
bash tools/test-drift.sh          → 22 通过 / 0 失败
                                    ─────────────────
                                    133 通过 / 0 失败
```

覆盖的关键断言（节选）：

- 判决解析 3 条旧绕过路径全部转为**正确拦截**
- 空模板占位（散文含 🔴）**不**被误计为阻塞项
- 自陈 `PASS` + Must-Fix 区有 🔴 → deny；合并报告干净但并行报告有 🔴 → 仍 deny
- `verifier` 判决 `PARTIAL` → deny（旧实现 `ask` = 放行）
- `current_phase` 为空 / 显式清空 → deny（旧实现放行）
- `verifier_loop_count: "abc"` → 不崩溃、按 0 处理
- 拼错的 `implementr` → deny（旧实现 allow 全部）
- `main` 分支派 implementer → deny；`impl-phase-1` → allow
- UI Phase：缺 `ui-spec`/`visual-baseline` → deny；DAG 缺 `ui` 字段 → deny（旧实现当作 `false` 静默放行）
- `shell-guard`：`/etc/shadow`、`find /`、`chmod -R /etc`、`git commit` → `ask`；`rm -rf /`、`git stash` → `deny`；正常命令不误伤
- 消息含双引号时输出**仍是合法 JSON**（`failClosed` 前提）

另做冒烟：`session-recovery.sh` 在有/无活跃工作流、以及状态文件损坏（fail-loud）三条路径下均输出合法 JSON。

---

## 5. 未做 / 待决

> ⚠️ 本表为 **v8 首轮**的清单，其中第 5、6 条已于 §6 复核时修正（`subagentStop` 能力确实可用；`tech-debt-registry` 创建已接、缺的是校验）。

| # | 项 | 状态 |
|---|---|---|
| 1 | **「调度者不得自己写实现代码」的程序化强制** | **未做**（决策：不启用）。现状仍为 Rules 层劝阻，无 hook 拦截 —— 见 §8.3 的复核与残留风险 |
| 2 | Trae 侧同步 | **未做**（按决策延后，见 §3） |
| 3 | Trae 独有机制反向移植到 Cursor（drift / subagent-contract / templates） | 部分落地：`drift-reminder.sh` 已补（§8.2）；`subagent-contract.sh` / `templates/` 仍待决 |
| 4 | `Edit` matcher 在 Cursor 上不触发（F2） | 保留条目作防御，未改由 `Write` 覆盖 |
| 5 | `subagentStop` 的「下一步引导」能力空置 | **已决**：不补推进器，只补**提醒器**（§8.2） |
| 6 | `tech-debt-registry.md` 只创建、无校验/强制 | **已落地**：gate 在 `hg3=passed` 时校验登记（§8.3） |

---

# 7. 待用户决策（**已于 v8.2 全部决策，见 §8**）

## 7.1 是否补一个「下一步引导」hook（`subagentStop` + `followup_message`）

> ✅ **已决（v8.2）**：补，但只做**提醒器**（`drift-reminder.sh`），不做推进器。见 §8.2。

- **能力确实存在**（§6.3 F-2），且这正是 `pipeline-advance.sh` 想做但做错的事。
- **但有一个真实张力**：`followup_message` 会**自动继续对话**（受 `loop_limit` 约束）。
  而本工作流的铁律是「HG 必须停下等用户确认」—— 一个说「下一步去派 implementer」的自动续跑消息，
  会**主动对抗 Human Gate 纪律**。
- 可行的安全形态：只在**不需要用户确认**的步骤自动续跑（如 implementer 完成 → 提示合并 4 视角 reviewer），
  在 HG 节点前**只提醒「该停下报告用户」而不推进**。但这需要相当细致的 `status` + 产物存在性判断。
- 现状兜底：always-applied 的 `spec-workflow.mdc` 文本规则（抗压缩，但无程序化纠偏）。

## 7.2 `tech-debt-registry.md` 的强制化

> ✅ **已决（v8.2）**：在 gate 的 `hg3=passed` 处做程序化校验。见 §8.3。

- 现状：`/feature` 会复制模板；gate 完全不检查；也没有任何 hook 保证 implementer 登记新桩。
- 可选处置：gate 在 `hg3=passed` 时检查 registry 是否被本 Phase 更新过（靠 `last_update` 或条目计数），
  或把「登记桩」纳入 reviewer 的 must-fix 判据。

## 7.3 过期文档残留的处置

> ✅ **已决（v8.2）**：删除 + 修正剩余陈旧引用。见 §8.1。

| 目标 | 现状 | 处置 |
|---|---|---|
| `AGENTS.md` 的旧编排章节（约 250 行） | 旧版流程描述：已废弃的 agent 名、旧状态文件路径、「2 个 Human Gate」 | **已删除**，改写为与 `.cursor/` 一致的现行描述 |
| 已废弃架构档（432 行） | 全面过期（旧路径、旧 Agent 链、2 个 Human Gate） | **已删除** |
| `.specdev/specs/workflows.json` | 与磁盘实际漂移：`specs/` 下 7 个工作流目录，文件里只有 4 条记录 | 未处置（见 §8.6 P3） |


## 附：本次未采纳的备选方案（留档）

| 备选 | 为何未采纳 |
|---|---|
| hg3 用 `ask` 交用户裁决 | F5：`preToolUse` 的 `ask` 不执行 → 用 `deny` + 明确消息 |
| 删除 `session-recovery.sh` | 它是压缩/新会话的唯一恢复点，价值明确 |
| 保留心跳、改为在 deny 上也附消息 | deny 消息本就是黑盒；心跳的价值不成立 |
| `grep -P` 换 `-E` 之外再包一层 shellcheck | 收益低于维护成本；改为在库文件头立铁律 + 测试覆盖 |

---

# 6. v8.1 勘误与追加发现（事后整体复核）

> 本节是一次「回过头来核实自己上一轮结论」的结果。
> 结论：**上一轮有 5 条断言是错的**，其中 2 条已经造成真实回归、1 条涉及「声称的替代方案其实从未生效」。
> 教训与 §1 的 F5 同源，只是这次踩坑的是我自己：**「看起来在工作」的代码最危险，包括我写的。**

## 6.1 我引入的真实回归（已修 + 补测试）

| # | 回归 | 后果 | 修法 |
|---|---|---|---|
| R1 | 在 Edit/Write 分支用 `read_status` 失败 → deny，未区分「状态文件不存在」 | **`/feature` 根本无法启动**：初始化顺序是 ①建目录 → ②写 active-workflow → ③初始化 current-status.json，第③步时文件尚不存在 → 必然 deny。v7 用 `if [ -f "$STATUS_FILE" ]` 跳过校验，反而没这个问题 | 文件不存在 → 判定为初始化路径，但**严格限定形状**：不得标 HG=passed、不得设 current_phase；其余照旧拒绝 |
| R2 | 新增的「显式清空 current_phase → deny」未加 `-n "$CURRENT_PHASE"` 前提 | **规划阶段写状态全被拦**：`requirement-analysis` 期间 `current_phase` 本就是 `""`，属于正常状态 | 仅当「原本有值的 phase 被清空」才拦 |

**为什么测试当时没抓到**：`test-gate.sh` 的沙箱**总是预先创建好 status 文件并带非空 phase**，bootstrap 路径完全没被覆盖。
已补 4 个用例（§test-gate 1b/1c），并把「测试夹具的初始状态」列为后续写门禁测试的必查项。

## 6.2 上一轮未发现、仍然存在的 fail-open（已修）

| # | 漏洞 | 说明 |
|---|---|---|
| R3 | content **非空但不是合法 JSON** 时静默放行 | 所有 `grep -qE '"hg3"...'` 都不匹配 → 结论退化为「没有推进动作」→ allow。v7 同样存在，v8 首版未修。现改为 `jq empty` 校验，失败即 deny（对 current-status.json 而言 content 必为完整文件，无合法放行场景） |

## 6.3 被证伪的断言（重要）

| # | 上轮断言 | 事实 | 影响 |
|---|---|---|---|
| **F-1** | 「`sessionStart` 的 `emit_anchoring_block` 承载了下一步引导，可替代 `pipeline-advance.sh`」 | ⚠️ **该注入链路从未生效**。`session-recovery.sh` 输出的是 Claude Code 约定的 `hookSpecificOutput.additionalContext` + 顶层 `additionalContext`（camelCase），而 Cursor 文档中 sessionStart 的输出 schema 是 `additional_context`（snake_case）——文档全文 `hookSpecificOutput` / `additionalContext` **各出现 0 次**。且 sessionStart 语义是「新建 composer 会话时」，**不是**压缩后、也不是子Agent 返回后 | 它**不是**任何东西的替代。已改为文档字段（§6.4），但它仍未覆盖「子Agent 返回后」这个场景 |
| **F-2** | 「Cursor 侧删掉 advance 即可，无需替代」 | `subagentStop` **明确支持** `followup_message`（仅 `status=completed` 时消费，受 `loop_limit` 约束，默认 5）。即：**能力存在，坏的只是那 363 行的实现**（用错输入字段 + 输出成纯文本） | 删除实现是对的，但**能力目前空置**。是否要补一个正确实现，见 §7 待决 |
| **F-3** | 「gate 是瘦身对象」 | gate **变大了**：525 → 608 行。净减来自删除 `pipeline-advance.sh`(−363) | 不影响正确性，但「做减法」应精确表述为**仓库级**，不是 gate 级 |
| **F-4** | 「`tech-debt-registry.md` 实际未被维护 → 未处理」 | **创建是接好的**：`/feature` 第 5 步会把 `.specdev/tech-debt-registry-template.md` 复制过去 | 真正缺的不是创建，而是**校验/强制**（gate 完全不检查它，也无 hook 保证 implementer 登记新桩） |
| **F-5** | 「`.trae` 侧 advance 绑在 `Stop`，F3/F4 对它不成立」 | 结论仍成立，但**理由要换**：Cursor 的 `stop` 与 `subagentStop` **都**支持 `followup_message`；Trae 的 advance 之所以没坏在这一点上，是因为它输出纯文本给 Trae 的 Stop 消费（Trae 协议不同），而不是因为 Cursor 不支持 | 结论不变，措辞需修正 |

## 6.4 本轮修正的其他问题

| # | 问题 | 处置 |
|---|---|---|
| D1 | `session-recovery.sh` 注入字段名错误（见 F-1） | 改为 `additional_context`；**不保留 camelCase 镜像** —— 未被消费的字段不是兼容层，是假象 |
| D2 | 3 处文档仍描述旧判决语义（「多值枚举 → 无可解析判决 → **拦截失效**」） | v8 下「无法解析」= **deny**（硬阻断），不会失效。已改正 `.cursor/rules/spec-workflow.mdc` ×2 + `.cursor/commands/implement.md` ×1，并补上「证据优先」双判说明 |
| D3 | `.cursor/rules/spec-workflow.mdc` 命令表缺 `/wiki` | 实际 9 个命令、表中 8 个 → 已补 |
| D4 | `.cursorrules`（Always Apply）与现行规则冲突：自称 6 个子Agent、3 个 Human Gate、`specs/` 路径 | 已重写为精简入口（11 agent / 4 HG / `.specdev/specs/`） |
| D5 | 新增 `tools/test-hook-contract.sh` | **契约测试**：断言「事件 × 允许输出字段」。这类 bug（字段名写错 → 静默失效）单元测试测不出，且已在 F-1 上真实发生。同时断言 hooks.json 的事件名都是真实存在的、注册脚本都在磁盘上 |

## 6.5 复核确认无误的部分

- v7 的 `Shell` 分支确实只是 `allow_with_heartbeat`（HEAD 源码：`:93-97`）→ 删除不丢逻辑
- `/tmp/.cursor-pipeline-heartbeat` 在 Cursor 侧**无任何消费者** → 删除无影响
- `verdict-parse.sh` 的 4 个函数**全部保留**（v7 也恰好是 4 个），调用方仅 gate 一处 → 无签名破坏
- `context-snapshot.sh` 使用的状态变量（`CURRENT_STAGE`/`HG1-3`/`CURRENT_PHASE`/`LOOP_COUNT`）在 `status-read.sh` 改动后全部仍被导出 → 无破坏
- `preCompact` / `sessionStart` 均为**真实事件名**（文档确认）
- `beforeShellExecution` 支持 `ask` 且真实生效（文档示例即 `gh` 命令需批准）→ `shell-guard.sh` 用 `ask` 正确
- `/feature` 初始化顺序（先 active-workflow 后 status）与最终清理顺序（先 hg3=passed 后清 active-workflow）**都与门禁相容**

---

# 8. v8.2 — 四项决策落地 + 本轮整体复核

> 触发：用户要求「再从整体上 review 一遍 spec 驱动开发流程，确认细节，是否存在遗漏，第二点瘦身动作是否执行了确认影响」。
> 本节先记四项决策的落地，再记**本轮复核新发现的漂移**（不在前几轮清单里）。

## 8.1 决策一：删除过期历史文档 + 修正剩余陈旧引用

| 动作 | 结果 |
|---|---|
| 删除已废弃架构档（432 行） | ✅ 已删。全仓 grep 验证无残留链接 |
| `AGENTS.md` 的过期编排章节 | ✅ 已移除；KB/MCP 章节改写为 Cursor 现状（同步由调度者直接执行） |
| `.cursorrules` | ✅ 重写为精简入口（11 agent / 4 HG / `.specdev/specs/`） |

**本轮新发现的残留（已修）**：

| # | 漂移 | 为什么危险 |
|---|---|---|
| N1 | `.cursor-plugin/plugin.json` 仍是旧世界：**6 个 agent**（实际 11）、**「3 Human Gate」**（实际 4）、`reviewer` 描述为「三视角审查」（实际四视角并行）、hooks 描述里写着「**自动推进**」（该机制已删）、命令只列 `/feature` `/bugfix`（实际 9 个）、路径写 `specs/requirements.md` | 这是**对外发布**的插件清单。它错 = 用户装到的能力描述与实际不符，且「自动推进」这句话本身就是已被证伪的承诺 |
| N2 | `.cursor/commands/feature.md` 两处声称「**hook 自动触发** HG-1.5/HG-2」「**hook 自动触发 HG-3 停止**」 | 与同文件 `:53`「没有 hook 会代你推进」**自相矛盾**。这正是「宣称了却没落地的机制」的同一类错误，只是换了层 |
| N3 | `session-recovery.sh` 注入的状态表**不含 HG-1.5**；`emit_anchoring_block` 的「三条铁律」写「**三个节点**」，且 architecture-design / phase-implementation 两段都**不提 HG-1.5 与原型门禁** | 锚定块是**压缩后唯一存活的信息面**（sessionStart + `recovery-instructions.md`）。它漏掉 UI 的两个停止点 → 恢复后最容易跳过的恰好是这两个。**已修 + 已加测试护栏**：`test-hook-contract.sh` 现断言两处锚定文本都含「HG-1.5」「原型确认」（`+4` 项断言）—— 这类「规则升级了但锚定块没跟着升」的漂移此前完全无测试覆盖 |
| N4 | `.cursor/agents/reviewer.md`、`.cursor/templates/phase-requirements.md`、`.cursor/skills/project-build&#124;test/SKILL.md` 仍写已废弃的 agent 名 `validator` | 该名字在当前模板中**不存在** → 引用它的 agent 会去找一个不存在的角色。`.trae/` 侧早已改成 `verifier`，`.cursor/` 侧漏改。（初版把 `code2prompt/SKILL.md` 也列在此处属**误判** —— 该文件从未含废弃 agent 名，见 §11.2） |
| N5 | `.cursor/skills/project-build&#124;test/SKILL.md` 被当成**本仓库的记事本**：写满 `specs/validation/...`、旧插件脚本、`/home/chendc/.nvm/...` 绝对路径等**只有本仓库才成立**的内容，且逐条标为「✅ 已验证」 | 这两个 skill 是**发给下游工程的模板**（`setup.sh` 整体拷贝 `.cursor/`）。模板里写本仓库的知识 = 每个下游项目开局就带一叠指向不存在路径的「已验证」条目 —— 比空文件更有害。**已还原为空骨架**（§11） |
| N6 | `feature.md` 初始化步骤有两个「4.」；**完全没写** `git checkout -b impl-<phase>` 与 HG-3 的 commit/merge | 分支隔离是 gate **硬校验**项（分支不对直接 deny），但用户实际执行的命令文档里没有它 |

## 8.2 决策二：`subagentStop` 只补「提醒器」，不补「推进器」

新增 `.cursor/hooks/drift-reminder.sh`（137 行，`failClosed:false`）并注册。

- 只检测三类**产物层面的矛盾**（D1 有 `review-*.md` 无 `review.md`；D2 `MUST-FIX` 但 `loop_count=0`；D3 原型未确认却已有审查/验证产物）
- 防刷屏靠 payload 自带的 `loop_count`（真实协议字段，非自建状态文件）→ 每个子Agent 最多提醒一次
- 消息恒定以「**停下核对并向用户报告**」结尾，**不复述下一步该委托谁** —— 它是刹车不是油门
- 用 `test-drift.sh`（22 项）断言了「消息不含任何推进型指令」这条契约

**关键取舍**：Cursor 的 `subagentStop` 确实支持 `followup_message` 自动续跑（F-2 已证），但用它去推「下一步派谁」会**主动对抗 HG 纪律**。所以能力保留、方向收窄。

## 8.3 决策三：gate 程序化校验技术债登记

`pipeline-gate.sh` 在写入 `hg3=passed` 时新增两级校验：

1. `tech-debt-registry.md` 必须存在（缺失 → deny，提示从模板复制）
2. 本 Phase 产物（`implementation.md` / `review.md` / `verification.md`）中出现的每个 `@STUB(...)`
   都必须在注册表中找得到（查无 → deny 并列出未登记标记）

**不做什么**：不扫源码（成本高、误伤大）、不要求「本 Phase 必须有新增条目」（无债的 Phase 是正常的）。
**意义**：「桩必须先登记」从文本约束变成**验收前置条件** —— 这是本项目里第一个「文档纪律」被翻译成程序化门禁的例子。

## 8.4 决策四：Trae 侧同步延后

`.trae/` 本轮**零改动**（`git status` 已确认）。§3 的同步清单继续有效，
但注意 §3.4 的警告仍然成立：**Trae 的 `pipeline-advance.sh` 不要照删**（事件协议不同）。

## 8.5 本轮复核确认无误的部分（含实测账目）

- **删除项无残留消费者**：全仓 grep `heartbeat` / `cursor-pipeline-heartbeat` / `pipeline-advance`（在 `hooks.json`、`setup.sh`、`plugin.json` 中）→ **均为 0 命中**
- **手写 JSON 字面量已收敛**：全仓 `{"permission"` 只出现在 `lib/emit.sh` 自身的降级分支（预期）
- **hooks.json 与磁盘一致**：5 个事件、5 个脚本全部存在（`test-hook-contract.sh` 断言）
- **增删账（实测，取代此前口算）**：

| 层 | 前 | 后 | Δ |
|---|---|---|---|
| hooks（含 `lib/`） | 1680 | 1651 | **−29** |
| ├ gate 本体 | 525 | 640 | +115 |
| └ 删除 `pipeline-advance.sh` | 363 | 0 | −363 |
| 新增测试 `tools/` | 0 | 721 | +721 |
| 新增本变更文档 | 0 | 469 | +469 |
| 删除过期架构文档 | 432 | 0 | −432 |
| **已跟踪文件合计** | — | — | **−511** |
| **仓库整体（含新增）** | — | — | **+868** |

- **测试从 0 到 133 项断言**：门禁自身在被测之前，其「正确性」只是声称

## 8.6 本轮**未**处置（明确留待决策）

| # | 项 | 现状与风险 |
|---|---|---|
| P1 | **调度者可自行伪造 agent 产物** | `pipeline-gate.sh:216-219` 只校验 `current-status.json`；其余写入一律 `allow`。即：调度者可以自己写 `implementation.md` / `review.md` / `verification.md`（含 `## 判决：PASS`），再由 gate 校验通过 → **HG-3 的「流程完整性」校验是「文件存在 + 判决行可解析」，无法区分作者**。这与 §5#1「不启用实现代码强制」同源，但危害面更大（可凭空造出一次审查+验证）。**部分收紧是可行的**（deny 对 `phases/**` 下除 `review.md` 外的写 —— `review.md` 本就是调度者的合并产物），但**前提是先实测 `preToolUse` 能否区分调用者**（若不能区分，则该规则会连 reviewer 自己的写入一起拦掉，属不可用）。**未实测，故未实施** |
| P2 | `.prototype-approved` 门禁钥匙可自行铸造 | 由 `touch` 创建，`shell-guard.sh` 未把该路径列为敏感。与 P1 同一类：门禁的钥匙在门禁的射程外 |
| P3 | `.specdev/specs/workflows.json` 与实际漂移 | 磁盘 7 个工作流目录，索引只有 4 条；`"status":"active"` 的 `pipeline-resume-robustness` 无维护机制 |
| P4 | Trae 独有机制反向移植（`subagent-contract.sh` / `templates/`） | 未决 |
| P5 | `.windsurfrules`（第三种平台的镜像） | 仅 15 行 KB 约定，与开发流程无关，暂无漂移风险；但它同样是一个会独立演化的「真相」 |

## 8.7 本轮的元结论

这轮复核抓到的 **N1~N6 全部不是 hook 逻辑错误，而是「同一件事在多个文件里各写一份」造成的描述漂移**：
gate 改了，`feature.md` 没改；`subagentStop` 删了，`plugin.json` 还说「自动推进」；HG 变成 4 个，锚定块还说 3 个。

即本项目最强调的 single source of truth，在**文档层并不成立** —— rule 文本 / agent 定义 / 命令文档 / 插件清单 / skill 内容是五份会独立演化的副本。
hook 代码有测试兜底（133 项断言），**文档没有**。若要继续做减法，下一个该减的就是「同一规则的副本数量」，
而不是再加一个「文档一致性检查 hook」（那只是把副本数量变成六份）。

---

# 9. v8.3 — 平台范围收敛与文档清理

> 触发：用户要求把已废弃平台的残留内容从仓库中清除。

## 9.1 收敛后的平台范围

模板现在**只支持两个平台**，两者独立维护、不会自动同步：

| 平台 | 载体 | 安装 |
|---|---|---|
| Cursor（首选） | `.cursor/` + `.cursorrules` + `.cursor/mcp.json` | `bash setup.sh --cursor` |
| Trae | `.trae/` + `.mcp.json` | `bash setup.sh --trae` |

- `setup.sh` 的模式只剩 `--cursor` / `--trae` / `--all`（`--all` = 前两者）；已移除的第三个模式
  连同其安装函数、`.gitignore` 注入逻辑一并删除
- 根目录的第三平台配置文件已删除；`.mcp.json` 保留为 Trae / Claude Code / Windsurf 的共用镜像

## 9.2 本轮清扫的陈旧引用（均为「指向不存在路径」）

| # | 位置 | 问题 |
|---|---|---|
| C1 | `.cursorrules` | 顶部警示仍在指向已删除的目录与文档 |
| C2 | `README.md` | 文件清单列了已删除的文件；「使用方法」里还有对应的安装步骤；一处「已废弃 agent 名」清单已无意义（那些名字全仓已不存在） |
| C3 | `AGENTS.md` / `KB_SYNC_STRATEGY.md` / `README.md` | 多处「本模板没有 X agent」的**否定式指名**（指向一个已不存在的角色）→ 改写为「同步由调度者直接执行」，不再指名 |
| C4 | `.cursor/skills/code2prompt/SKILL.md` | 用法示例引用的是 `.opencode/templates/repo-map.hbs`（路径已不存在）→ **仅改路径前缀**为 `.cursor/`，与 `.trae/` 侧保持逐字对称（`sed 's/\.trae/.cursor/g'` 后两份完全一致）。初版曾顺手删掉 `--template` 参数并改写说明段 —— 属**过度编辑模板**，已回退（§11.2） |
| C5 | `KB_SYNC_STRATEGY.md` §5 / §9 | 「XX 侧实现」整节指向已不存在的文件与不存在的渲染规范文档 → 改写为 Cursor 侧**实际生效**的四个载体 |
| C6 | `KNOWNBASE_WRITE_PATH_EXPLAINED.md` | 推荐元数据里的 `sourceTool` 值写的是已废弃平台 → 改为 `cursor` |
| C7 | `.cursor/skills/project-build&#124;test/SKILL.md` | 见 §8.1 N5。初版按其「correction over accumulation」规则清理过期条目后，**填入本仓库当前有效的构建/测试命令** —— 这仍是在把模板当记事本，只是内容更新了而已，且更难察觉（看起来是「新鲜知识」）。**最终处置：整份还原为空骨架**（§11） |
| C8 | `templates/validation-report.md`（根目录） | **孤儿文件**：全仓零引用（`README.md` 里的 `templates/` 是 `.cursor/templates/`，与根目录无关），且阶段清单写的是已废弃的 agent 链 → **已删除**（连同空目录）。verifier 的实际产物契约在 `.cursor/agents/verifier.md` 与 `verification.md` 中，不依赖此模板 |

## 9.3 验证

- 全仓 grep（排除第三方图标名列表 `lobe-icons.json`）：`.cursor/`、根目录文档、`setup.sh`、`.specdev/` **零命中**
- `bash -n` 全部 hook / 测试脚本 / `setup.sh` 通过；全部 `.json` / `.jsonc` 通过 `jq empty`
- 5 个测试套件 **133 通过 / 0 失败**（清扫后回归）

## 9.4 本轮**未**做的事

| 项 | 原因 |
|---|---|
| `.trae/` 中同类的陈旧 agent 名（`.trae/templates/phase-requirements.md`、`.trae/agents/reviewer.md`） | Trae 侧同步本轮延后（同 §8.4）。**这两处是已知的待同步项**，修复方式与 `.cursor/` 侧完全相同 |

---

# 10. 提交前发现：`drift-reminder.sh` 从未生效（同一个死法）

> 触发：commit 前核对文件权限时发现 —— **不是测试发现的**。这一点本身比 bug 更重要。

## 10.1 事实

| 项 | 值 |
|---|---|
| 症状 | `drift-reminder.sh` 权限为 `-rw-rw-r--`，其余 4 个被注册的 hook 均为 `-rwxrwxr-x` |
| 后果 | Cursor 直接执行注册路径，无 `x` 位 → **hook 被静默跳过**。§8.2 交付的漂移提醒器**从建立起一次都没运行过** |
| 讽刺之处 | 它取代的 `pipeline-advance.sh` 也从未生效过（§2.6，原因不同：字段 + 协议错误）。**同一位置连续两个 hook 都是死的，且都没人发现** |

## 10.2 为什么 133 项断言全绿却没抓到

`tools/test-*.sh` 内部一律用 **`bash <script>`** 调用被测 hook —— 这个调用方式**不依赖可执行位**。
即：测试覆盖了「脚本逻辑对不对」，完全没覆盖「脚本能不能被启动」。
`test-hook-contract.sh` 当时只断言了注册脚本**在磁盘上**（`-f`），没断言**可执行**（`-x`）。

→ 这是一个**测试盲区**，而非漏写一条断言。所有「被测对象如何被调用」与「生产环境如何调用」不一致的地方，
都可能有同类盲区。

## 10.3 处置

1. `chmod +x .cursor/hooks/drift-reminder.sh`
2. `test-hook-contract.sh` 的断言从 `-f` 升级为 `-f && -x`，失败消息直接给出 `chmod +x <path>` 修法
3. **红色验证（先证明断言有用）**：修复前跑测试 → `26 通过 / 1 失败`，精确指向 `drift-reminder.sh`
4. **绿色验证**：`chmod +x` 后 → `27 通过 / 0 失败`（断言总数仍 133，未新增条目，只是加强了原条目）

## 10.4 教训

本轮此前**没有任何文件**写过「新增 hook 必须 `chmod +x`」这条纪律。
（初版此处称「`project-build/SKILL.md` 里早就写着」—— 那两行是**本次审查时我自己补进去的**，并非既有知识；该文件随后已被还原成骨架，见 §11。属**倒果为因**，已更正。）

即：`drift-reminder.sh` 的可执行位从建立起就没人负责 —— **纪律不只没有被强制，它根本不存在**。
比「写在文档里的纪律等于没有纪律」更糟一层：**没写下来的纪律，连被读到然后忽略的机会都没有**。

唯一有效的补救是把它放进**会失败的测试**里（`test-hook-contract.sh` 的 `-f && -x` 断言，失败消息直接给出 `chmod +x <path>`），而不是放进文档。
文档只能告诉读到它的人；测试会拦住没读到的人。

---

# 11. 模板 skill 还原：把「发给下游的文件」当成了记事本

> 触发：用户指出 —— 「`project-build` / `project-test` 这两个东西不是给你用来记录的，是一个模板，使用这套框架的工程用的」。

## 11.1 事实

`.cursor/skills/project-build/SKILL.md` 与 `.cursor/skills/project-test/SKILL.md` **不是本仓库的知识库**，
而是随模板分发给下游工程的**空骨架**：`AGENTS.md` 明确写着「These skills start as empty skeletons」，
且 `setup.sh` 会把整个 `.cursor/` 拷进目标工程 —— 任何写进去的内容都会出现在**每一个下游项目**里。

这两份文件此前（本次改造之前就已）被填满了**只对本仓库成立**的内容：

| 文件 | 被写进去的内容 | 性质 |
|---|---|---|
| `project-build` | `OpenCode 插件（.mjs）— 无需构建`、`Phase 1: 文本规则硬化`、`/home/chendc/.nvm/versions/node/v20.16.0/bin/node` | 路径/概念均只在本仓库存在 |
| `project-test` | `specs/validation/phase2-enforcement-plugin/test-scripts/*.mjs`、120/120 passed、`validator` | 同上 |

对照之下，`.trae/skills/project-build/SKILL.md` **是干净的骨架**（逐节 `*（项目首次使用时由 implementer 填充）*`）——
即两侧本来就不一致，`.cursor/` 侧被污染而 `.trae/` 侧没有。

**本轮初版处置是错的**：我按 skill 自己的「correction over accumulation」规则**清理过期条目后补入当前有效命令**
（`tools/test-*.sh`、`jq` 依赖、git `--trailer` 绕过写法……）。这仍是在把模板当记事本 ——
只是把**陈旧的本仓库知识**换成了**新鲜的本仓库知识**，而且更难发现：新内容看起来都是对的。

## 11.2 为什么这是两类不同的错误

| | 初版做的事 | 正确的事 |
|---|---|---|
| 性质 | 内容**更新**（清旧 + 填新） | 内容**清空**（还原骨架） |
| 后果 | 下游项目拿到一份「看起来新鲜」的本仓库知识，且被标为 ✅ 已验证 | 下游项目拿到空骨架，首次使用时自行填充 |
| 为何难察觉 | 内容真实、路径有效、格式合规 —— 所有检查都会通过 | — |

同一批文件里还有第三类错误：`code2prompt/SKILL.md`。它确实含**不存在的路径**（`.opencode/templates/...`，属实打实的过期引用，该改），
但我顺手**连 `--template` 参数一起删掉并改写了说明段** —— 超出了「修一条死路径」的必要范围。
`.trae/` 侧对该文件只做了一件事：路径前缀不同，其余逐字一致。已按此回退。

## 11.3 处置与验证

| # | 动作 |
|---|---|
| 1 | `.cursor/skills/project-build/SKILL.md` 还原为空骨架 → 与 `.trae/` 侧 **`diff` 完全一致**（保留的 `validator`→`verifier` 改名属 N4，两侧本就应一致） |
| 2 | `.cursor/skills/project-test/SKILL.md` 还原为空骨架（`.trae/` 侧那份同样被污染，见 §11.4） |
| 3 | `.cursor/skills/code2prompt/SKILL.md` 回退过度编辑 → 与 `.trae/` 侧 `sed 's/\.trae/.cursor/g'` 后 **逐字一致** |
| 4 | 修正 §8.1 N4/N5、§9.2 C4/C7、§10.4 中因本次回退而失效的叙述 |

验证：`diff .cursor/skills/project-build/SKILL.md .trae/skills/project-build/SKILL.md` → 无输出（一致）；
残留自检 `rg 'trailer|cursor-agent-exec|tools/test-|2\.25\.1' <两份文件>` → 零命中。

## 11.4 后续处置（用户确认后已执行）

| 项 | 说明 |
|---|---|
| `.trae/skills/project-test/SKILL.md` | **已还原为空骨架** → 与 `.cursor/` 侧逐字一致（骨架内容本身是**平台中立**的：讲的是「首次使用时由 verifier 填充」，不涉及任何一侧专属路径） |
| `setup.sh` 的 `chmod +x` 不对称 | **已补齐**：`install_cursor()` 现在与 `install_trae()` 对称，都有 `chmod +x <hooks>/*.sh` 兜底。红/绿验证（源仓库**故意抹掉** `x` 位，再安装）：**兜底生效** → `-rwxrwxr-x`；**把 `chmod` 停掉（模拟修复前）** → 仍是 `-rw-rw-r--`，即 5 个 hook **全部会被 Cursor 静默跳过**。这证明该缺失不是理论风险，而是可复现的失效路径 —— 与 §10 的 `drift-reminder.sh` 同一个死法，只是发生在**下游每一个工程**上 |

> ⚠️ 注意 `install_*()` 的 `chmod` 只覆盖 `hooks/*.sh`。`hooks/lib/*.sh` 是被 `source` 的共享库，**不需要** `x` 位，刻意不加。

## 11.5 教训

模板仓库里存在两类文件，它们的**正确修改方式相反**：

- **本仓库的产物**（`tools/`、`README.md`、规则文件）—— 持续更新，越准确越好
- **发给下游的模板**（`.cursor/skills/*`、`.cursor/agents/*`、`.trae/*`）—— 改动必须问「这对**下游项目**成立吗」，
  内容只能增删**结构性**的东西（路径前缀、agent 名），不能塞入本仓库的运行事实

判断方法很简单：`setup.sh` 会不会把它拷进目标工程。会 → 它是对外接口。

## 11.6 顺带查清：`+1233 / −1882` 是怎么来的

该数字长期挂在文件顶部（标为「已跟踪文件」），且**与本文件后来给出的总数 `+2675 / −1984` 冲突** ——
但当时没有说明为什么，读者无从判断哪个对。

实测溯源（逐候选命令比对）：

| 命令 | 结果 |
|---|---|
| `git diff --shortstat 6084ab9 36b3f62` | `33 files changed, 2704 insertions(+), 1882 deletions(-)` |
| **`git diff --shortstat --diff-filter=MDR 6084ab9 36b3f62`** | **`25 files changed, 1233 insertions(+), 1882 deletions(-)`** ← 就是这个 |
| `git diff --shortstat 6084ab9 36b3f62 -- .cursor/` | `18 files changed, 1731 / 1093` |
| `git diff --shortstat 6084ab9 36b3f62 -- '*.sh'` | `14 files changed, 1672 / 1023` |

即：**数字本身是实测的，错的是标签** —— `--diff-filter=MDR` 把 8 个新增文件（+1542）整个排除了，
却写成了「已跟踪文件」，读者按普通 `git diff --shortstat` 一算必然不同。
同时 `−1882` 与 `−1984` 的差（102）正是此后才删除的 `templates/validation-report.md` ——**同一段文字里混了两个时点的快照**。

**教训**：本文件通篇在要求 agent「不实测不下断言」，但**实测了却不说清了口径，等于没测**。
可复现的标准不是给出数字，而是给出**能重跑出该数字的命令**。已按此改写顶部章节（口径表 + 重跑指引）。

---

# 12. v8.4 — 设计前探查：把「不许猜」变成可验收的形式

## 12.1 起因（用户发现，且比"少一个步骤"更严重）

> 「当前需求分析到方案设计这个阶段，我发现少了一个针对需求或者方案设计的探查过程……
> 需要先探查清楚才能实现方案设计，不是简单的基于需求凭空想象的」

**用户是对的，但实测发现真正的问题是「探索能力被门禁自己关闭了」。**

### 实测证据（payload 探针，非文档推断）

`code-explorer.md` 声明了 4 个调用场景，逐一派发实测：

| 场景 | `current_phase` | 实测 | 原因 |
|---|:--:|:--:|---|
| 独立调研 `/research`（**新建 session**） | 空 | allow | 状态文件不存在 → 走了 bootstrap 早退分支（**副作用，非设计**） |
| 独立调研 `/research`（**已有工作流内**） | 空 | **deny** | 无条件 `validate_phase_id` |
| 架构设计前 `/plan` | 空 | **deny** | 同上 |
| Bug 修复前 `/bugfix` | 空 | **deny** | 同上（HG-2 才设 `current_phase`） |
| Phase 实施前 | 已设 | allow | — |

即：**`/plan` 的文档流程从写下那天起就无法按写法执行**，而且方向是反的 ——
**拦住了探索，放行了无输入的设计**（`plan-generator` 被 allow）。

`test-gate.sh` 从未发现此事，因为它的 3 条 code-explorer 断言**全部**是 Phase 场景（第 10 组）。

### 陈旧引用（与 §8.1 的 N2 同源，属同一类错误）

- `research.md:11-13` 早就写着「`/research` 可独立使用，也可作为 `/feature` 的前置步骤；
  产出文件可被后续的 `requirement-analyst`、`plan-generator` 直接读取」—— **能力设计过、文档写过、从未接线**。
- `code-explorer.md` 自相矛盾：调用场景表说 `/research` 输出到**工作流级**路径，
  「路径解析」节却写死 `phases/<current_phase>/repo-exploration.md`（`current_phase` 为空时拼成 `phases//`）。
- `research.md` 说报告 8 章节，`code-explorer.md` 说 10 章节。
- `plan-generator.md:175`（原）要求「引用 `code-explorer` 的 UI 组件库识别结果」——
  但 §11 是 **Phase 级**产物，而设计阶段**根本跑不了** code-explorer。**一句在它运行时不可能成立的引用。**

## 12.2 结构性根因

不只是"漏写一句委托"，而是三个层面同时缺位：

| 层面 | 现状 | 后果 |
|---|---|---|
| **契约** | `plan-generator` 的 Input 里**没有任何代码库信息** | 它按契约执行，**不觉得自己在猜** —— 契约缺失比纪律缺失更根本 |
| **能力** | `code-explorer` 被设计成 Phase 专属（路径 / 必读 / "不做全库扫描"） | 即使放开 gate 也不适合做设计前调研，范围与视角都不同 |
| **强制** | `design.md` 只校验「≥10 行 + 含 `##`」 | 架构决策可完全基于推断通过 HG-2 |

**代价被推迟到最贵的地方**：`reviewer-design` 的职责是「对照 design.md **与代码库既有约定**」——
设计阶段**不查**代码库约定，却由审查阶段**拿代码库约定去判它**。

> **与 UI 链的对照**：本项目为「没有视觉基准就没有可比对的 target」建了完整一条链
> （HG-1.5 + 原型门禁 + reviewer-visual + 强制视觉验证），理由正是**没有真相源**。
> **代码库这条链面对的是同一个问题**，而它的返工成本比界面高一个量级。

## 12.3 落地实现（用户四项决策）

> 用户选择：**不新增 agent，复用 `code-explorer`/`research`**；**产物自证 (a)**；
> **工作流级路径**；**新增并列的 `Stop & Explore`**；**`requirement-analyst` 不纳入**。

| # | 决策 | 实现 |
|:--:|---|---|
| 1 | 复用而非新增 agent | `code-explorer` 改为**双模式**（workflow 级 / phase 级），复用既有章节集 |
| 2 | 产物自证（可验收） | `design.md` 必须有 `## 现状依据`，每条带 `路径:行号` → 门禁校验 **L1–L5** |
| 3 | 工作流级路径 | `<spec_dir>/repo-exploration.md`（与 `/research` 既有文档一致，非新建子目录） |
| 4 | 独立于 escalation 的通路 | `escalation-protocol.md` 新增 `Stop & Explore`，**不占用 escalation 通道** |
| 5 | 需求阶段不读代码 | `requirement-analyst` **不**纳入（只谈「要什么」，避免把设计约束提前混进需求） |

### 门禁校验（L1–L5）

`check_design_evidence()`，在写入 `hg2=passed` 时触发：

| 级别 | 校验 | 抓住 |
|:--:|---|---|
| L1 | `## 现状依据` 章节存在 | 完全没写 |
| L2 | 至少 1 条证据 | 空壳应付 |
| L3 | 每条形如 `` `路径:行号` `` | 写成散文（「现有架构大致是…」） |
| **L4** | **路径在仓库中真实存在** | **编造路径** |
| **L5** | **行号 ≤ 文件实际行数** | **编造行号** |

**逃生舱**：显式声明「本设计不依赖现有代码：<理由>」→ 跳过 L2–L5。
`「无依据」必须是显式声明而非沉默默认` —— 与 `ui_relevant: false` 必须写理由同理；
**沉默的空白无法被质疑，显式声明可以被反驳。**

### 🔴 边界（必须写进代码注释，否则会重演「以为有保护」）

> 门禁保证 **「证据指向真实位置」**，**不保证** **「证据支持该断言」**。
> 后者是语义判断，属 `reviewer-design` 的职责 —— 门禁做不到，也不该假装能做到。

此边界同时写入 `pipeline-gate.sh` 注释、`AGENTS.md`、`plan-generator.md`。

### `Stop & Explore` — 两条通路的区分

| | `Stop & Escalate` | `Stop & Explore` |
|---|---|---|
| 场景 | 我查不出来 / 不该我决定 | **我能查到，但我现在还没查** |
| 动作 | 交出去 | **停下来先查**，查完继续 |
| 需要用户决策？ | 是（🟡/🔴/⚫） | **否** |
| 过 Human Gate？ | — | **否**（HG-1 与 HG-2 之间自然发生） |

**为什么必须独立而非复用**：Trigger C 的判据是 *missing information **cannot be reasonably inferred***。
而设计阶段最常缺的信息（「现有模块怎么做的」）**是能查到的，只是没查** ——
若无这条通路，agent 只剩「**猜**」或「**为一件本该自己查的事打扰用户**」，两者都是失败。

🔴 **批量收集铁律**：收集完全部待确认项后**一次性**返回。
agent 不能派发 agent（`Task` 属调度者），逐个返回会让一次设计产生 3–5 次往返 ——
**机制会因太贵而在实际使用中被绕过**。这是"省钱"与"机制可用"的分界。

## 12.4 被证伪的自有断言（重要，我写错了一条）

我最初把「`readonly: false` 与其 Must Not Do 的只读声明矛盾」列为顺带修复项，
计划把 `code-explorer.md` 改成 `readonly: true`。**查证后放弃 —— 这条断言是错的。**

- 平台文档：`readonly: true` = **no file edits, no state-changing shell commands**（默认 false）
- 若照此修改，**`code-explorer` 将无法写入自己的 `repo-exploration.md`** —— 直接破坏其核心职能
- 实测：**11 个 agent 全部是 `readonly: false`**，无一例外，且全仓库**没有任何文档解释该字段语义**

正确处置：**保留 `readonly: false`**，并在 `code-explorer.md` 明确「只读」的**真实含义**：

> 你的只读性指的是**不修改产品代码与配置**（Must Not Do），**不是** frontmatter 层面的写权限
> —— 你**必须**能写自己的 `repo-exploration.md`。本仓库所有 agent 均为 `readonly: false`，
> 正是因为每个 agent 都要落盘产物。

**教训**：这与 §6.3「被证伪的断言」同类 —— 我看到 frontmatter 与正文"矛盾"就假设是漂移，
**没有先查该字段的语义**。若当时直接改了，会静默破坏 code-explorer 的写报告能力，
而这类破坏在测试里**表现不出来**（测试用 `bash <script>`，绕过 agent 机制）。

**顺带发现**：`plan-generator.md` **没有** `Stop & Escalate` 章节，但 `escalation-protocol.md`
声称 "referenced by every agent definition"。已补 4 条触发条件（需求自相矛盾 / 需求与现状冲突 /
Phase 拆分不可行 / 选型无客观依据）。

## 12.5 测试（+9 条，含红绿双向验证）

`test-gate.sh` 从 41 → **50**；全库 **133 → 142 断言**。

| 组 | 断言 | 性质 |
|:--:|---|:--:|
| 14 | 空 `current_phase` + `architecture-design` → allow | 绿（**旧实现 deny**） |
| 14 | 空 `current_phase` + `requirement-analysis` → allow | 绿（**旧实现 deny**） |
| 14 | 空 `current_phase` + `phase-implementation` → deny | 红（状态损坏，fail-closed） |
| 15 | 无「现状依据」章节 → deny | 红 |
| 15 | 只有散文、无 `路径:行号` → deny | 红 |
| 15 | 证据指向不存在路径 → deny | 红（**L4**） |
| 15 | 行号超出文件行数 → deny | 红（**L5**） |
| 15 | 显式声明「不依赖现有代码」→ allow | 绿（逃生舱） |
| 15 | 证据真实且行号合法 → allow | 绿 |

### ⚠️ 测试改造：夹具必须"合格"，而不是给门禁开后门

夹具原 `design.md` 是 `# 设计\n\n## 架构决策\n…`，**没有现状依据章节** → 触发 5 条既有用例
（`hg3` 完整流程等）与本文件列出的（见 §7 数字字段污染用例）连锁失败。

**处置原则**：夹具要还原「**合格的设计长什么样**」，而**不是**加一个绕过标记让门禁在测试里永远为绿。
故改为写入**真实存在**的证据（沙箱内 `src/demo.ts:1`、`src/config.ts:2`）。

> ⚠️ 证据只能用**沙箱内**路径：`PROJECT_ROOT` 取自 payload 的 `workspace_roots[0]`（指向沙箱），
> 引用真实仓库路径会被 **L4 正确拒绝**。这一点在改造中实测踩到。

### 红绿双向验证（证明断言不是"空绿"）

绿了不等于断言有用 —— 必须证明 deny **来自新校验**，而非 `check_file_valid` 因别的原因碰巧拦住。
逐用例抓取 `user_message`：

| 用例 | design.md 行数/含`##` | 实际拒绝消息 |
|---|---|---|
| 无章节 | 14 行 / 1 个 `##` | 「⛔ 设计缺少「现状依据」章节…」 |
| 只有散文 | 18 行 | 「⛔ 「现状依据」章节无有效证据…」 |
| 路径不存在 | 20 行 | 「⛔ 「现状依据」含不存在的路径：`src/nope.ts`」 |
| 行号越界 | — | 「⛔ 「现状依据」行号越界：`src/config.ts:99` 指向 … 只有 2 行」 |
| 合法证据 | 21 行 / 2 个 `##` | **allow** |

前 4 条的行数/标记均**满足** `check_file_valid(design.md, 10, "##")` 的要求，
因此拒绝只能来自新校验 —— **断言非空**。

实现中用 **here-string 而非管道**遍历证据：管道会创建子 shell，
`emit_deny` 的 `exit 0` 只能退出子 shell，门禁将带 0 退出码继续 → **静默放行**。

## 12.6 改动清单

| 文件 | 改动 |
|---|---|
| `.cursor/hooks/pipeline-gate.sh` | code-explorer 双模式分流；新增 `check_design_evidence()`（L1–L5）；hg2 挂载；硬阻断清单 +1 |
| `.cursor/agents/code-explorer.md` | 双模式定义；修路径矛盾（按 mode 分流）；统一章节集 10+§11；`readonly` **保留 false** + 澄清"只读"含义；新增 Workflow Mode 章节 |
| `.cursor/agents/plan-generator.md` | Input 加 workflow 级报告必读；新增「现状依据」（含 L1–L5 说明）；新增 `Stop & Explore`；**补 `Stop & Escalate` 章节**；修 :175 悬空引用 |
| `.cursor/snippets/escalation-protocol.md` | 新增 `Stop & Explore`（与 Escalate 并列 + 区别表 + 触发信号 + 输出格式 + 批量铁律 + 调度者响应） |
| `.cursor/templates/solution-design-output.md` | 「架构摘要」前插入 `## 现状依据` 章节模板 |
| `.cursor/commands/feature.md` | 第四步加 workflow 级调研 + STOP & EXPLORE 响应 + 门禁提示；Per-Phase 调研标注 phase 模式与两份产物区别 |
| `.cursor/commands/plan.md` | 第一步改为 workflow 模式 + 真路径；加 STOP & EXPLORE 响应；hg2 门禁提示 |
| `.cursor/commands/bugfix.md` | 第三步**补「先调研再分析根因」**（此前让 plan-generator 凭空分析根因） |
| `.cursor/commands/research.md` | 修 8→10 章节；加 tech-debt-registry 初始化；workflow 模式标注；修正 `requirement-analyst` 声明（不读它） |
| `.cursor/rules/spec-workflow.mdc` | 双模式章节重写；阶段表 +1 行；阶段图更新；HG 流程加 workflow 调研；Stop & Explore 铁律 |
| `AGENTS.md` | 门禁失败史 +2 条；新增「设计必须基于现状的可验收化」小节（含边界）；权威表补备注；断言数 133→142 |
| `.cursorrules` | agent 表 + 工作流图 + Stop & Explore 说明；断言数 133→142 |
| `tools/test-gate.sh` | 沙箱加真实文件；夹具改合格设计；+9 断言（第 14/15 组） |

## 12.7 回归风险

| 风险 | 评估 |
|---|---|
| 放开 code-explorer 是否削弱保护？ | **低**。它是只读 agent；实施类 agent 的阶段检查（`CURRENT_STAGE != phase-implementation` → deny）**独立且不受影响**，无法借此绕过 HG-2 |
| 存量工作流受影响？ | **无**。依据校验只在写入 `hg2=passed` 时触发；已过 HG-2 的工作流不会再次写入该状态 |
| 依据章节变成走过场？ | **本方案的主要残余风险**。L4/L5 只能挡「编造位置」，挡不住「位置真实但证明力弱」。缓解：确认度规则（⚠️/❓ 不得作依据）+ reviewer-design 复核 |
| Trae 侧 | **未同步**（用户决策延后，见 §8.4） |

## 12.8 教训

1. **契约缺失比纪律缺失更根本**。`plan-generator` 不觉得自己在猜 —— 它的 Input 里根本没有代码库。
   补纪律（「不许猜」）不如补契约（「必读调研报告」）。
2. **门禁会以「保护」之名关闭能力**。`validate_phase_id` 被无条件套上时，
   没人意识到它把 4 个场景里的 3 个关掉了。**加校验收紧之前，先问「哪些合法场景会走到这里」。**
3. **测试覆盖的盲区 = 无人质疑的场景**。3 条断言全是 Phase 场景 → 另外 3 个死场景零护栏。
   **断言"某分支能被测到"与"该分支的所有合法输入都被测到"是两件事。**
4. **改了 frontmatter 却不知其语义 = 盲改**。`readonly` 那条若照改，会静默破坏写报告能力，
   而测试用 `bash <script>` **绕过 agent 机制，表现不出来**（与 §10 的 `chmod` 教训同源）。
5. **"绿"不等于"断言有用"**。5 条既有用例曾因夹具失真而失败；修复时若给门禁加绕过标记，
   新校验会在测试里**永远是绿的** —— 那才是真正危险的假安全。
6. **「稳定值」必须两端钉死**。我在本轮同时犯了 §11.6 批评过的同一类错：
   把终点写成 `HEAD` 的命令标为「稳定」，**提交后它立刻失效**。
   §11.6 的教训是「口径要说清」，但**口径说清了仍会漂** —— 只要端点没钉死。
   可复现的完整条件是：**命令 + 两端 commit + 排除项**，缺一不可。

