// ============================================
// KB Sync Runtime Plugin - 稳定版 v2
// ============================================
// 
// 功能：
// 1. 压缩事件处理 - 自动同步到 KB
// 2. 压缩前注入最小化上下文保留指令（只保留 pipeline 状态，不保留规则）
//
// 设计原则：
// - 不在系统提示中注入 KB sync 规则（规则已在 AGENTS.md 和 knowledge-manager.md 中定义）
// - 压缩后 orchestrator 应通过读取 specs/current-status.md 恢复状态，而非依赖压缩总结
// - 手动同步触发依赖 AGENTS.md 中的规则引导 AI 识别
//

const KB_API_BASE = process.env.KB_API_URL || "http://localhost:4000/api/v1"
const RUNTIME_SYNC_ENDPOINT = `${KB_API_BASE}/sync/runtime-event`

function textPart(text, metadata = {}) {
  return {
    type: "text",
    text,
    synthetic: true,
    metadata,
  }
}

function getProjectName(directory = "") {
  const parts = directory.split("/").filter(Boolean)
  return parts[parts.length - 1] || "unknown"
}

function extractSessionContent(messages = [], directory = "") {
  const sections = []
  const summaryMsg = messages.find((message) => message?.info?.summary?.body)

  if (summaryMsg?.info?.summary) {
    const summary = summaryMsg.info.summary
    if (summary.title) sections.push(`摘要: ${summary.title}`)
    if (summary.body) sections.push(summary.body)
    if (Array.isArray(summary.diffs) && summary.diffs.length > 0) {
      sections.push("相关文件:")
      for (const diff of summary.diffs.slice(0, 20)) {
        if (diff?.file) sections.push(`- ${diff.file}`)
      }
    }
  }

  const recentMessages = messages.slice(-10)
  const userRequests = []
  const toolActions = []

  for (const message of recentMessages) {
    if (message?.info?.role === "user") {
      for (const part of message.parts || []) {
        if (part?.type === "text" && typeof part.text === "string" && part.text.length > 10) {
          userRequests.push(part.text.slice(0, 200))
        }
      }
    }

    if (message?.info?.role === "assistant") {
      for (const part of message.parts || []) {
        if (part?.type === "tool-invocation" || part?.type === "tool") {
          toolActions.push(part.title || "unknown")
        }
      }
    }
  }

  if (userRequests.length > 0) {
    sections.push("", "用户请求:")
    for (const request of userRequests.slice(-3)) {
      sections.push(`- ${request}`)
    }
  }

  if (toolActions.length > 0) {
    const counts = {}
    for (const action of toolActions) {
      counts[action] = (counts[action] || 0) + 1
    }

    sections.push("", `关键操作: 共执行 ${toolActions.length} 次工具调用`)
    for (const [action, count] of Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)) {
      sections.push(`- ${action} (${count}次)`)
    }
  }

  if (directory) {
    sections.push("", `目录: ${directory}`)
  }

  return sections.join("\n").trim()
}

async function postToKB(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(`KB API error ${response.status}: ${text}`)
  }

  return response.json()
}

function buildCompressionSyncPrompt() {
  return [
    "Automatic KB sync trigger: session.compacted.",
    "Before continuing normal work, sync the compacted session into the knowledge base through knowledge-base MCP.",
    "Required actions:",
    "1. Read .opencode/project-config.md for the project identifier.",
    "2. Read .opencode/snippets/kb-sync-sop.md for the sync procedure.",
    "3. Create one new Snapshot Doc in Projects/<project>/Snapshots/.",
    "4. Find or create today's Daily Digest in Daily/<YYYY>/<YYYY-MM>/.",
    "5. If a durable architectural or product conclusion emerged, also sync a Decision Doc or Topic Doc.",
    "6. State whether the sync succeeded.",
  ].join("\n")
}

export const KbSyncRuntimePlugin = async (ctx) => {
  const projectName = getProjectName(ctx?.directory || "")

  return {
    // 压缩事件处理 - 尝试自动同步
    event: async ({ event }) => {
      if (event?.type !== "session.compacted") return

      const sessionID = event.properties?.sessionID
      if (!sessionID || !ctx?.client?.session) return

      try {
        const messagesResult = await ctx.client.session.messages({
          path: { id: sessionID },
          query: { limit: 50 },
        })

        const messages = messagesResult?.data || []
        const summary = extractSessionContent(messages, ctx?.directory || "")

        if (!summary || summary.length < 20) return

        const lastAssistant = [...messages].reverse().find((m) => m?.info?.role === "assistant")
        const model = lastAssistant?.info?.modelID || undefined

        await postToKB(RUNTIME_SYNC_ENDPOINT, {
          triggerType: "compression",
          stage: "compression",
          project: projectName,
          sessionId: sessionID,
          summary,
          directory: ctx?.directory || "",
          timestamp: new Date().toISOString(),
          model,
          sourceTool: "opencode-plugin",
          objectHints: ["snapshot", "daily"],
        })
      } catch (_error) {
        // HTTP 同步失败时，通过 MCP 方式同步（静默失败，不阻塞）
        try {
          if (ctx?.client?.session?.promptAsync) {
            await ctx.client.session.promptAsync({
              sessionID,
              directory: ctx?.directory || "",
              agent: "knowledge-manager",
              parts: [
                textPart(buildCompressionSyncPrompt(), {
                  source: "kb-sync-runtime",
                  triggerType: "compression",
                }),
              ],
            })
          }
        } catch {
          // 静默失败 - 会话内的规则仍会要求同步
        }
      }
    },

    // 压缩前注入最小化上下文保留指令
    "experimental.session.compacting": async (_input, output) => {
      if (output?.context && Array.isArray(output.context)) {
        output.context.push(
          "COMPACTION DIRECTIVE: After compaction, the orchestrator MUST read specs/current-status.md to recover pipeline state. " +
          "The compacted summary should ONLY contain: (1) the user's original requirement in one sentence, (2) the current pipeline stage name, (3) the last completed action and its result. " +
          "Do NOT preserve workflow rules, KB sync procedures, architecture descriptions, or agent definitions in the summary — these are already defined in system prompt files and will be available after compaction. " +
          "Minimal context = faster recovery = less re-compression.",
        )
      }
    },
  }
}

export default KbSyncRuntimePlugin
