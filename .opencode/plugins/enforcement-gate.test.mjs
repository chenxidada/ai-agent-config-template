// ============================================
// Enforcement Gate Plugin — Integration Test
// ============================================
// Tests the primary external behavior: permission.ask sets correct output.status
// Runs via: node .opencode/plugins/enforcement-gate.test.mjs
// ============================================

import { EnforcementGatePlugin } from './enforcement-gate.mjs';
import { mkdir, writeFile, rm } from 'fs/promises';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { tmpdir } from 'os';
import { join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ============================================
// Mock context factory
// ============================================

function createMockCtx(directory) {
  return {
    directory: directory || process.cwd(),
    client: {
      session: {
        info: async ({ path: { id } }) => ({
          data: { agent: "orchestrator" },
        }),
      },
    },
  };
}

function createMockCtxNoApi(directory) {
  return {
    directory: directory || process.cwd(),
    client: null,  // No client API → isOrchestrator should return true (conservative)
  };
}

// ============================================
// Test runner
// ============================================

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) {
    passed++;
    process.stdout.write(`  ✅ ${msg}\n`);
  } else {
    failed++;
    process.stderr.write(`  ❌ FAIL: ${msg}\n`);
  }
}

async function runIntegrationTests() {
  console.log('\n========================================');
  console.log('Enforcement Gate Plugin — Integration Tests');
  console.log('========================================\n');

  // --- Setup: temp directory with controlled specs/current-status.md ---
  const testDir = join(tmpdir(), `enforcement-test-${Date.now()}`);
  await mkdir(testDir, { recursive: true });
  const specsDir = join(testDir, 'specs');
  await mkdir(specsDir, { recursive: true });

  const ctx = createMockCtx(testDir);
  const hooks = await EnforcementGatePlugin(ctx);

  // ============================================
  // Test Group 1: Edit Gate
  // ============================================
  console.log('\n--- Edit Gate ---');

  // 1a: specs/current-status.md — ALLOW
  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'edit', pattern: 'specs/current-status.md', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'allow', `Edit specs/current-status.md → allow (got: ${output.status})`);
  }

  // 1b: specs/**/ (directory creation) — ALLOW
  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'edit', pattern: 'specs/phases/phase-1/slices/sub-1/', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'allow', `Edit specs/.../directory/ → allow (got: ${output.status})`);
  }

  // 1c: src/main.c — DENY
  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'edit', pattern: 'src/main.c', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'deny', `Edit src/main.c → deny (got: ${output.status})`);
  }

  // 1d: AGENTS.md — DENY
  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'edit', pattern: 'AGENTS.md', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'deny', `Edit AGENTS.md → deny (got: ${output.status})`);
  }

  // 1e: .opencode/plugins/kb-sync-runtime.mjs — DENY
  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'edit', pattern: '.opencode/plugins/kb-sync-runtime.mjs', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'deny', `Edit .opencode/plugins/... → deny (got: ${output.status})`);
  }

  // 1f: specs/some-other-file.md — DENY (not current-status.md)
  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'edit', pattern: 'specs/design/some-design.md', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'deny', `Edit specs/design/some-design.md → deny (got: ${output.status})`);
  }

  // 1g: absolute path ending in specs/current-status.md — ALLOW
  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'edit', pattern: '/home/user/project/specs/current-status.md', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'allow', `Edit /abs/path/specs/current-status.md → allow (got: ${output.status})`);
  }

  // ============================================
  // Test Group 2: Bash Gate — Allowlist
  // ============================================
  console.log('\n--- Bash Gate: Allowlist ---');

  const allowedCommands = [
    ['mkdir -p specs/phases/1/slices/1/', 'mkdir -p specs/'],
    ['git branch', 'git branch'],
    ['git branch -a', 'git branch -a'],
    ['git checkout -b impl-foo', 'git checkout'],
    ['git merge impl-foo', 'git merge'],
    ['git log --oneline -10', 'git log'],
    ['git stash', 'git stash'],
    ['git stash pop', 'git stash pop'],
    ['which node', 'which'],
    ['ls', 'ls'],
    ['ls -la', 'ls -la'],
    ['cat specs/current-status.md', 'cat specs/current-status.md'],
  ];

  for (const [cmd, label] of allowedCommands) {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'bash', pattern: cmd, sessionID: 's1', title: 'bash' },
      output
    );
    assert(output.status === 'allow', `Bash "${label}" → allow (got: ${output.status})`);
  }

  // ============================================
  // Test Group 3: Bash Gate — Denied (not in allowlist)
  // ============================================
  console.log('\n--- Bash Gate: Denied (not allowed) ---');

  const unknownCommands = [
    ['echo hello', 'echo'],
    ['find . -name "*.js"', 'find'],
    ['grep -r foo', 'grep'],
  ];

  for (const [cmd, label] of unknownCommands) {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'bash', pattern: cmd, sessionID: 's1', title: 'bash' },
      output
    );
    assert(output.status === 'deny', `Bash "${label}" → deny (got: ${output.status})`);
  }

  // ============================================
  // Test Group 4: Bash Gate — Denylist (explicitly blocked)
  // ============================================
  console.log('\n--- Bash Gate: Denylist ---');

  const blockedCommands = [
    ['git push', 'git push'],
    ['git push --force', 'git push --force'],
    ['rm -rf build/', 'rm -rf'],
    ['cmake --build build/', 'cmake'],
    ['make', 'make'],
    ['make -j4', 'make -j4'],
    ['ninja', 'ninja'],
    ['ctest', 'ctest'],
    ['pytest tests/', 'pytest'],
    ['npm run build', 'npm run'],
    ['npm test', 'npm test'],
    ['npm start', 'npm start'],
    ['yarn install', 'yarn'],
    ['pnpm install', 'pnpm'],
    ['python3 script.py', 'python3'],
    ['python script.py', 'python'],
    ['node server.js', 'node'],
    ['gcc -o main main.c', 'gcc'],
    ['g++ -o main main.cpp', 'g++'],
    ['cat src/main.c', 'cat on non-specs'],
    ['npx something', 'npx'],
    ['docker ps', 'docker'],
    ['kubectl get pods', 'kubectl'],
    ['curl http://example.com', 'curl'],
    ['wget http://example.com', 'wget'],
  ];

  for (const [cmd, label] of blockedCommands) {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'bash', pattern: cmd, sessionID: 's1', title: 'bash' },
      output
    );
    assert(output.status === 'deny', `Bash "${label}" → deny (got: ${output.status})`);
  }

  // ============================================
  // Test Group 5: Task Gate — Discussion Mode (default)
  // ============================================
  console.log('\n--- Task Gate: Discussion Mode ---');

  // Allowed in discussion
  const discussionAllowed = [
    'repo-explorer',
    'code-analyst',
    'requirement-analyst',
    'solution-architect',
    'program-planner',
    'task-planner',
    'knowledge-manager',
  ];
  for (const agent of discussionAllowed) {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'task', pattern: agent, sessionID: 's1', title: 'task' },
      output
    );
    assert(output.status === 'allow', `Task "${agent}" in discussion → allow (got: ${output.status})`);
  }

  // Blocked in discussion
  const discussionBlocked = ['implementer', 'reviewer', 'validator'];
  for (const agent of discussionBlocked) {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'task', pattern: agent, sessionID: 's1', title: 'task' },
      output
    );
    assert(output.status === 'deny', `Task "${agent}" in discussion → deny (got: ${output.status})`);
  }

  // ============================================
  // Test Group 6: Task Gate — Execution Mode
  // ============================================
  console.log('\n--- Task Gate: Execution Mode ---');

  // Write specs/current-status.md with execution mode
  await writeFile(
    join(specsDir, 'current-status.md'),
    'Current Stage: execution\nMode: execution\nPipeline: feature-xyz is in execution phase',
    'utf-8'
  );

  // Create fresh plugin instance to re-read state
  const execCtx = createMockCtx(testDir);
  const execHooks = await EnforcementGatePlugin(execCtx);

  // In execution mode, all agents allowed
  const allAgents = [...discussionAllowed, ...discussionBlocked];
  for (const agent of allAgents) {
    const output = { status: 'ask' };
    await execHooks['permission.ask'](
      { type: 'task', pattern: agent, sessionID: 's1', title: 'task' },
      output
    );
    assert(output.status === 'allow', `Task "${agent}" in execution → allow (got: ${output.status})`);
  }

  // ============================================
  // Test Group 7: Event Handlers (no crash)
  // ============================================
  console.log('\n--- Event Handlers ---');

  {
    // file.edited — should not throw
    try {
      await hooks['event']({ event: { type: 'file.edited', properties: { file: 'src/main.c', sessionID: 's1' } } });
      assert(true, 'file.edited event handler does not crash');
    } catch (e) {
      assert(false, `file.edited event handler crashed: ${e.message}`);
    }
  }

  {
    // file.edited — specs/ file (no log expected, but no crash)
    try {
      await hooks['event']({ event: { type: 'file.edited', properties: { file: 'specs/current-status.md', sessionID: 's1' } } });
      assert(true, 'file.edited on specs/ does not crash');
    } catch (e) {
      assert(false, `file.edited specs/ handler crashed: ${e.message}`);
    }
  }

  {
    // command.executed
    try {
      await hooks['event']({ event: { type: 'command.executed', properties: { command: 'git log', sessionID: 's1' } } });
      assert(true, 'command.executed event handler does not crash');
    } catch (e) {
      assert(false, `command.executed handler crashed: ${e.message}`);
    }
  }

  {
    // session.compacted — resets state
    try {
      await hooks['event']({ event: { type: 'session.compacted', properties: { sessionID: 's1' } } });
      assert(true, 'session.compacted event handler does not crash');
    } catch (e) {
      assert(false, `session.compacted handler crashed: ${e.message}`);
    }
  }

  {
    // permission.updated
    try {
      await hooks['event']({ event: { type: 'permission.updated', properties: {} } });
      assert(true, 'permission.updated event handler does not crash');
    } catch (e) {
      assert(false, `permission.updated handler crashed: ${e.message}`);
    }
  }

  // ============================================
  // Test Group 8: First-run (no current-status.md)
  // ============================================
  console.log('\n--- First-run (no current-status.md) ---');

  {
    const freshDir = join(testDir, 'fresh');
    await mkdir(freshDir, { recursive: true });
    const freshCtx = createMockCtx(freshDir);
    const freshHooks = await EnforcementGatePlugin(freshCtx);

    // Should default to discussion mode (restrictive)
    const output = { status: 'ask' };
    await freshHooks['permission.ask'](
      { type: 'task', pattern: 'implementer', sessionID: 's1', title: 'task' },
      output
    );
    assert(output.status === 'deny', `First-run: implementer in default discussion → deny (got: ${output.status})`);
  }

  // ============================================
  // Test Group 9: No API client fallback (conservative = enforce)
  // ============================================
  console.log('\n--- No API client fallback ---');

  {
    const noApiCtx = createMockCtxNoApi(testDir);
    const noApiHooks = await EnforcementGatePlugin(noApiCtx);

    // Without client API, should still enforce gates (conservative)
    const output = { status: 'ask' };
    await noApiHooks['permission.ask'](
      { type: 'edit', pattern: 'src/main.c', sessionID: 's1', title: 'edit' },
      output
    );
    assert(output.status === 'deny', `No API: edit src/main.c → deny (conservative) (got: ${output.status})`);
  }

  // ============================================
  // Test Group 10: Session compaction → re-read state
  // ============================================
  console.log('\n--- Session Compaction State Recovery ---');

  {
    // Start with discussion mode
    await writeFile(
      join(specsDir, 'current-status.md'),
      'Current Stage: discussion\nMode: discussion',
      'utf-8'
    );
    const recovCtx = createMockCtx(testDir);
    const recovHooks = await EnforcementGatePlugin(recovCtx);

    // Verify discussion mode blocks implementer
    {
      const output = { status: 'ask' };
      await recovHooks['permission.ask'](
        { type: 'task', pattern: 'implementer', sessionID: 's1', title: 'task' },
        output
      );
      assert(output.status === 'deny', `Pre-compaction: discussion mode → deny implementer (got: ${output.status})`);
    }

    // Simulate compaction
    await hooks['event']({ event: { type: 'session.compacted' } });

    // Change current-status.md to execution mode (simulating orchestrator updating it)
    await writeFile(
      join(specsDir, 'current-status.md'),
      'Current Stage: execution\nMode: execution\nPipeline: feature in execution',
      'utf-8'
    );

    // After compaction, the NEXT permission.ask should re-read state
    // NOTE: This test uses the original hooks object. The compacted flag
    // is set, so the next permission.ask will call initState() again.
    {
      const output = { status: 'ask' };
      await hooks['permission.ask'](
        { type: 'task', pattern: 'implementer', sessionID: 's1', title: 'task' },
        output
      );
      // Should now be execution mode → allow
      assert(output.status === 'allow', `Post-compaction+execution: implementer → allow (got: ${output.status})`);
    }
  }

  // ============================================
  // Test Group 11: Unknown permission type (pass-through)
  // ============================================
  console.log('\n--- Unknown Permission Type ---');

  {
    const output = { status: 'ask' };
    await hooks['permission.ask'](
      { type: 'web_fetch', pattern: 'https://example.com', sessionID: 's1', title: 'web_fetch' },
      output
    );
    // Should not modify output.status (leave as-is, pass-through)
    assert(output.status === 'ask', `Unknown type web_fetch → pass-through (ask) (got: ${output.status})`);
  }

  // ============================================
  // Cleanup & Summary
  // ============================================
  try {
    await rm(testDir, { recursive: true, force: true });
  } catch (_e) {
    // ignore cleanup errors
  }

  console.log(`\n========================================`);
  console.log(`Results: ${passed} passed, ${failed} failed`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runIntegrationTests().catch(e => {
  console.error(`\n🔥 Test runner crashed: ${e.message}`);
  console.error(e.stack);
  process.exit(1);
});
