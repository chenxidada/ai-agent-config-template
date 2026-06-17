// ============================================
// Enforcement Gate Plugin v1.0
// ============================================
//
// 功能：
// 1. Edit Gate — 阻止 Orchestrator 编辑 specs/current-status.md 以外的文件
// 2. Bash Gate — 阻止 Orchestrator 运行非允许列表的命令（allowlist + denylist）
// 3. Task Gate — 讨论模式下阻止 dispatching implementer/reviewer/validator
// 4. Event Monitoring — 监控 file.edited / command.executed / session.compacted
// 5. Pipeline State Tracking — 从 specs/current-status.md 读取并追踪 pipeline 状态
//
// 设计原则：
// - Allowlist 为主：默认拒绝，明确允许
// - Fail-open：初始化失败时默认 discussion 模式，不阻塞操作
// - 可观测：违反日志通过 console.warn 输出
// - 共存：与 kb-sync-runtime.mjs 独立运行，不共享状态
//
// 设计文档：specs/design/enforcement-system-design.md §2
// ============================================

import { readFile } from 'fs/promises';
import { resolve } from 'path';

// ============================================
// Constants — Gate Rules
// ============================================

// Edit Allowlist: ONLY these paths are editable by the Orchestrator
// Rule: specs/current-status.md (exact match or ends-with)
// Rule: specs/**/ (directory creation patterns end with /)
const EDIT_ALLOWLIST = {
  currentStatus: (pattern) => {
    if (!pattern) return false;
    const normalized = pattern.replace(/\\/g, '/');
    return normalized === 'specs/current-status.md' || normalized.endsWith('/specs/current-status.md');
  },
  specsDir: (pattern) => {
    if (!pattern) return false;
    const normalized = pattern.replace(/\\/g, '/');
    return normalized.startsWith('specs/') && normalized.endsWith('/');
  },
};

// Bash Allowlist: Safe orchestration commands
const BASH_ALLOWLIST = [
  /^mkdir\s+-p\s+specs\//,
  /^git\s+branch/,
  /^git\s+checkout/,
  /^git\s+merge/,
  /^git\s+log/,
  /^git\s+stash/,
  /^which\s+/,
  /^ls(\s|$)/,
  /^cat\s+specs\/current-status\.md$/,
];

// Bash Denylist: Even within allowed categories, these are blocked
const BASH_DENYLIST = [
  /git\s+push/,
  /rm\s+-rf/,
  /cmake/,
  /\bmake\b/,
  /\bninja\b/,
  /ctest/,
  /\bpytest\b/,
  /npm\s+(run|test|start)/,
  /\byarn\b/,
  /pnpm\s/,
  /\bpnpm\b/,
  /\bpython3?\b/,
  /\bnode\s/,
  /\bgcc\b/,
  /\bg\+\+/,
  /cat\s+(?!specs\/current-status\.md)/,
  /\bnpx\b/,
  /\bdocker\b/,
  /\bkubectl\b/,
  /\bcurl\b/,
  /\bwget\b/,
];

// Task Gate: Agents blocked in Discussion mode
const DISCUSSION_BLOCKED_AGENTS = new Set([
  'implementer',
  'reviewer',
  'validator',
]);

// Allowed in all modes
const ALWAYS_ALLOWED_AGENTS = new Set([
  'repo-explorer',
  'code-analyst',
  'requirement-analyst',
  'solution-architect',
  'program-planner',
  'task-planner',
  'knowledge-manager',
]);

// ============================================
// Plugin State
// ============================================

function createState() {
  return {
    mode: 'discussion',       // 'discussion' | 'execution' | 'unknown'
    pipelineStage: 'idle',    // From specs/current-status.md
    violationLog: [],         // [{ timestamp, type, pattern, blocked }]
    initialized: false,       // Whether current-status.md has been read
  };
}

// ============================================
// State Initialization
// ============================================

async function initState(state, directory) {
  try {
    const statusPath = resolve(directory || '', 'specs/current-status.md');
    const content = await readFile(statusPath, 'utf-8');

    // Parse mode from content
    // "execution" or "实施" keywords trigger execution mode
    state.mode = /execution|实施/.test(content) ? 'execution' : 'discussion';

    // Parse pipeline stage
    const stageMatch = content.match(/Current Stage:\s*(.+)/);
    if (stageMatch) {
      state.pipelineStage = stageMatch[1].trim();
    }

    state.initialized = true;
  } catch (_err) {
    // First run — specs/current-status.md may not exist
    // Default to "discussion" (most restrictive)
    state.mode = 'discussion';
    state.pipelineStage = 'idle';
    state.initialized = true;
  }
}

// ============================================
// Session Identity Detection
// ============================================

async function isOrchestrator(ctx, sessionID) {
  try {
    if (ctx?.client?.session?.info) {
      const sessionInfo = await ctx.client.session.info({
        path: { id: sessionID },
      });
      return sessionInfo?.data?.agent === 'orchestrator';
    }
  } catch (_err) {
    // API unavailable — fallback to always enforce (conservative)
    // This means the gate applies to ALL sessions when we can't identify
    console.warn('[ENFORCEMENT] Cannot check session identity via API — enforcing on all sessions');
  }
  // If no client API available, enforce on all sessions (conservative strategy)
  return true;
}

// ============================================
// Gate: Edit Permission
// ============================================

function handleEditGate(input, output, state) {
  const pattern = input.pattern || '';

  // ALLOW: specs/current-status.md (exact or absolute path)
  if (EDIT_ALLOWLIST.currentStatus(pattern)) {
    output.status = 'allow';
    return;
  }

  // ALLOW: Creating specs/ directories (mkdir operations)
  if (EDIT_ALLOWLIST.specsDir(pattern)) {
    output.status = 'allow';
    return;
  }

  // DENY: Everything else
  output.status = 'deny';
  state.violationLog.push({
    timestamp: Date.now(),
    type: 'edit',
    pattern,
    blocked: true,
  });
  console.warn(`[ENFORCEMENT] Edit denied: "${pattern}" (session: ${input.sessionID})`);
}

// ============================================
// Gate: Bash Permission
// ============================================

function handleBashGate(input, output, state) {
  const cmd = (input.pattern || '').trim();
  if (!cmd) {
    output.status = 'deny';
    return;
  }

  const isAllowed = BASH_ALLOWLIST.some((p) => p.test(cmd));

  // If not in allowlist → deny immediately (no need to check denylist)
  if (!isAllowed) {
    output.status = 'deny';
    state.violationLog.push({
      timestamp: Date.now(),
      type: 'bash',
      pattern: cmd,
      blocked: true,
    });
    console.warn(`[ENFORCEMENT] Bash denied (not in allowlist): "${cmd}" (session: ${input.sessionID})`);
    return;
  }

  // Check denylist (secondary filter)
  const isBlocked = BASH_DENYLIST.some((p) => p.test(cmd));
  if (isBlocked) {
    output.status = 'deny';
    state.violationLog.push({
      timestamp: Date.now(),
      type: 'bash',
      pattern: cmd,
      blocked: true,
    });
    console.warn(`[ENFORCEMENT] Bash denied (on denylist): "${cmd}" (session: ${input.sessionID})`);
    return;
  }

  // Allowlist match + not on denylist → allow
  output.status = 'allow';
}

// ============================================
// Gate: Task Permission
// ============================================

function handleTaskGate(input, output, state) {
  // input.pattern may be a string or array of strings
  const agents = Array.isArray(input.pattern)
    ? input.pattern
    : [input.pattern];

  // In execution mode, allow all agents
  if (state.mode === 'execution') {
    output.status = 'allow';
    return;
  }

  // Discussion mode: block code-modifying agents
  for (const agent of agents) {
    if (DISCUSSION_BLOCKED_AGENTS.has(agent)) {
      output.status = 'deny';
      state.violationLog.push({
        timestamp: Date.now(),
        type: 'task',
        pattern: agent,
        blocked: true,
        reason: 'discussion_mode',
      });
      console.warn(`[ENFORCEMENT] Task denied (discussion mode): "${agent}" (session: ${input.sessionID})`);
      return;
    }
  }

  output.status = 'allow';
}

// ============================================
// Event Handlers
// ============================================

function handleFileEdited(event, state) {
  const filePath = event.properties?.file || '';
  const sessionID = event.properties?.sessionID || 'unknown';

  // Log writes outside specs/ and .opencode/ (for audit)
  // .opencode/ is excluded because plugin/config files are configuration
  if (!filePath.startsWith('specs/') && !filePath.startsWith('.opencode/')) {
    console.warn(`[ENFORCEMENT] Unauthorized file write detected: ${filePath} (session: ${sessionID})`);
    state.violationLog.push({
      timestamp: Date.now(),
      type: 'file.edited',
      pattern: filePath,
      blocked: false, // Wasn't blocked by permission.ask — detection only
    });
  }
}

function handleCommandExecuted(event, state) {
  const command = event.properties?.command || '';
  // Log for post-hoc audit
  state.violationLog.push({
    timestamp: Date.now(),
    type: 'command.executed',
    pattern: command,
    blocked: false, // The gate may not have caught this
  });
}

async function handleCompaction(state) {
  // Reset initialized flag → next permission.ask will re-read current-status.md
  state.initialized = false;
}

function handlePermissionUpdated(event) {
  // Log permission changes for audit
  const permId = event.properties?.permissionId || 'unknown';
  const status = event.properties?.status || 'unknown';
  console.warn(`[ENFORCEMENT] Permission updated: ${permId} → ${status}`);
}

// ============================================
// Plugin Export
// ============================================

export const EnforcementGatePlugin = async (ctx) => {
  const state = createState();

  return {
    /**
     * permission.ask — The core enforcement hook.
     *
     * Called by the framework before an agent performs a restricted action.
     * Sets output.status to "allow" or "deny" based on the gate rules.
     *
     * Only enforces rules on orchestrator sessions.
     * Non-orchestrator sessions pass through unchanged.
     *
     * Handles three permission types:
     *   - "edit": File edit operations → edit gate
     *   - "bash": Shell command execution → bash gate
     *   - "task": Agent dispatch → task gate
     */
    'permission.ask': async (input, output) => {
      try {
        // Lazy initialization: read specs/current-status.md on first call
        if (!state.initialized) {
          await initState(state, ctx?.directory || '');
        }

        // Only enforce on orchestrator sessions
        if (!(await isOrchestrator(ctx, input.sessionID))) {
          return;
        }

        switch (input.type) {
          case 'edit':
            handleEditGate(input, output, state);
            break;
          case 'bash':
            handleBashGate(input, output, state);
            break;
          case 'task':
            handleTaskGate(input, output, state);
            break;
          default:
            // Unknown permission type — pass through unchanged (fail-open)
            break;
        }
      } catch (err) {
        // Fail-open: plugin internal errors must not block the system
        console.error(`[ENFORCEMENT] Internal error in permission.ask: ${err.message}`);
        // Leave output.status as-is (the framework default)
      }
    },

    /**
     * event — Monitor and react to framework events.
     *
     * Handles:
     *   - file.edited: Log unauthorized writes outside specs/
     *   - command.executed: Log all commands for audit
     *   - session.compacted: Reset state to force re-read of current-status.md
     *   - permission.updated: Log permission changes
     */
    event: async ({ event }) => {
      try {
        if (!event?.type) return;

        switch (event.type) {
          case 'file.edited':
            handleFileEdited(event, state);
            break;
          case 'command.executed':
            handleCommandExecuted(event, state);
            break;
          case 'session.compacted':
            await handleCompaction(state);
            break;
          case 'permission.updated':
            handlePermissionUpdated(event);
            break;
        }
      } catch (err) {
        // Event handler errors must not disrupt pipeline
        console.error(`[ENFORCEMENT] Internal error in event handler (${event?.type}): ${err.message}`);
      }
    },
  };
};

export default EnforcementGatePlugin;
