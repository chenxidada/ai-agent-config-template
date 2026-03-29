const MANUAL_SYNC_RE = /(同步到知识库|同步知识库|总结并同步|提炼并同步|沉淀到\s*kb|sync to kb|sync to knowledge base|summarize and sync)/i
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

function collectText(parts = []) {
  return parts
    .filter((part) => part?.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n")
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

  const lastAssistant = [...recentMessages].reverse().find((message) => message?.info?.role === "assistant")
  const lastText = lastAssistant?.parts
    ?.filter((part) => part?.type === "text" && typeof part.text === "string")
    ?.map((part) => part.text)
    ?.join("\n")

  if (lastText && lastText.length > 50) {
    sections.push("", "最近回复摘要:", lastText.slice(0, 500))
    if (lastText.length > 500) sections.push("...")
  }

  if (directory) {
    sections.push("", `目录: ${directory}`)
  }

  return sections.join("\n").trim()
}

function buildRuntimeContract() {
  return [
    "KB sync runtime contract:",
    "- Treat knowledge-base MCP as the only official sync path.",
    "- Automatic compression trigger: on compression, reset, or handoff, use the runtime event sync flow to create one Snapshot Doc and update today's Daily Digest.",
    "- Automatic workflow checkpoint trigger: when requirement, architecture, implementation milestone, validation, or major debugging conclusion is completed, sync the stage result immediately through the high-level sync flow.",
    "- Manual user trigger: when the user explicitly asks to summarize and sync, execute KB sync immediately with the high-level sync tools.",
    "- A trigger is fulfilled only after actual MCP write actions run.",
    "- Do not mark a stage complete until required checkpoint sync has executed.",
    "- Follow the KB Sync SOP in .opencode/snippets/kb-sync-sop.md.",
  ].join("\n")
}

function buildManualSyncInstruction(userText) {
  return [
    "Manual KB sync trigger detected.",
    "Execute the sync now instead of deferring it.",
    "Steps:",
    "1. Extract only the durable, high-value information from the current request and recent session context.",
    "2. Choose the best matching object type: Task Doc, Topic Doc, Decision Doc, Snapshot Doc, or Daily Digest.",
    "3. Use the appropriate high-level sync entry to write the target object.",
    "4. Report sync success or failure clearly.",
    "User request:",
    userText || "<empty>",
  ].join("\n")
}

function buildCompressionSyncPrompt() {
  return [
    "Automatic KB sync trigger: session.compacted.",
    "Before continuing normal work, sync the compacted session into the knowledge base through knowledge-base MCP.",
    "Required actions:",
    "1. Use the runtime event sync flow with compression semantics.",
    "2. Ensure it creates one new Snapshot Doc in Projects/<project>/Snapshots/.",
    "3. Ensure it finds or creates today's Daily Digest in Daily/<YYYY>/<YYYY-MM>/.",
    "4. If a durable architectural or product conclusion emerged, also sync a Decision Doc or Topic Doc.",
    "5. State whether the sync succeeded.",
    "Follow .opencode/snippets/kb-sync-sop.md.",
  ].join("\n")
}

export const KbSyncRuntimePlugin = async (ctx) => {
  const projectName = getProjectName(ctx.directory)

  return {
    "experimental.chat.system.transform": async (_input, output) => {
      output.system.push(buildRuntimeContract())
    },

    "chat.message": async (_input, output) => {
      const userText = collectText(output.parts)
      if (!MANUAL_SYNC_RE.test(userText)) return

      output.parts.push(
        textPart(buildManualSyncInstruction(userText), {
          source: "kb-sync-runtime",
          triggerType: "manual",
        }),
      )
    },

    "command.execute.before": async (input, output) => {
      const raw = `${input.command || ""} ${input.arguments || ""}`.trim()
      if (!MANUAL_SYNC_RE.test(raw)) return

      output.parts.push(
        textPart(buildManualSyncInstruction(raw), {
          source: "kb-sync-runtime",
          triggerType: "manual-command",
        }),
      )
    },

    event: async ({ event }) => {
      if (event?.type !== "session.compacted") return

      const sessionID = event.properties?.sessionID
      if (!sessionID) return

      try {
        const messagesResult = await ctx.client.session.messages({
          path: { id: sessionID },
          query: { limit: 50 },
        })

        const messages = messagesResult?.data || []
        const summary = extractSessionContent(messages, ctx.directory)

        if (!summary || summary.length < 20) {
          return
        }

        const lastAssistant = [...messages].reverse().find((message) => message?.info?.role === "assistant")
        const model = lastAssistant?.info?.modelID || undefined

        await postToKB(RUNTIME_SYNC_ENDPOINT, {
          triggerType: "compression",
          stage: "compression",
          project: projectName,
          sessionId: sessionID,
          summary,
          directory: ctx.directory,
          timestamp: new Date().toISOString(),
          model,
          sourceTool: "opencode-plugin",
          objectHints: ["snapshot", "daily"],
        })
      } catch (_error) {
        try {
          await ctx.client.session.promptAsync({
            sessionID,
            directory: ctx.directory,
            agent: "knowledge-manager",
            parts: [
              textPart(buildCompressionSyncPrompt(), {
                source: "kb-sync-runtime",
                triggerType: "compression",
              }),
            ],
          })
        } catch {
          // Keep the runtime hook non-fatal; the in-session rules still require sync.
        }
      }
    },

    "experimental.session.compacting": async (_input, output) => {
      output.context.push(
        "Before compaction completes, preserve enough detail for KB sync. The next automatic step after compaction is a runtime event sync action that creates a Snapshot Doc and updates the Daily Digest following .opencode/snippets/kb-sync-sop.md.",
      )
    },
  }
}

export default KbSyncRuntimePlugin
