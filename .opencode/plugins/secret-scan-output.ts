/**
 * secret-scan-output.ts — opencode plugin
 *
 * Mirrors the behavior of .core/hooks/secret-scan-output.py.
 * Scans tool output for sensitive patterns after Read, Bash, and MCP
 * filesystem tool calls. Non-blocking — warns via stderr only.
 *
 * Sensitive patterns detected:
 *   - Git and GitHub personal access tokens
 *   - Client secrets, SP passwords, tokens as key=value or JSON fields
 *   - Storage connection strings
 *   - Private keys / certificates
 */

import { Plugin } from "@opencode/plugin"

const PATTERNS: Array<[RegExp, string]> = [
  [
    /glpat-[A-Za-z0-9_\-]{20,}/,
    "Git personal access token (glpat-…)",
  ],
  [
    /ghp_[A-Za-z0-9]{36}/,
    "GitHub classic personal access token (ghp_…)",
  ],
  [
    /github_pat_[A-Za-z0-9_]{82}/,
    "GitHub fine-grained personal access token (github_pat_…)",
  ],
  [
    /(?:client[_-]?secret|client[_-]?password|sp[_-]?secret)\s*[=:"]\s*\S+/i,
    "client secret or SP password value",
  ],
  [
    /(?:password|passwd)\s*[=:"]\s*(?!null|true|false|<)[^\s"',]{4,}/i,
    "password field with value",
  ],
  [
    /(?:token|api[_-]?key|access[_-]?key|pat)\s*[=:"]\s*[A-Za-z0-9+/\-_]{20,}/i,
    "token or API key value",
  ],
  [
    /DefaultEndpointsProtocol=https?;AccountName=/,
    "storage connection string",
  ],
  [
    /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----/,
    "private key material",
  ],
]

const WATCHED_TOOLS = new Set([
  "read",
  "bash",
  "mcp__filesystem__read_file",
  "mcp__filesystem__read_multiple_text_files",
  "mcp__filesystem__head_file",
  "mcp__filesystem__tail_file",
  "mcp__filesystem__search_files_content",
])

function extractText(value: unknown): string {
  if (typeof value === "string") return value
  if (Array.isArray(value)) return value.map(extractText).join("\n")
  if (value && typeof value === "object") {
    for (const key of ["content", "output", "result", "text"]) {
      if (key in (value as Record<string, unknown>)) {
        return extractText((value as Record<string, unknown>)[key])
      }
    }
    return JSON.stringify(value)
  }
  return String(value ?? "")
}

export default Plugin.define({
  id: "secret-scan-output",
  async setup(ctx) {
    await ctx.tool.hook("execute.after", (event) => {
      // Only completed calls produce output to scan; errors carry no output.
      if (event.status !== "completed") return

      const toolName = (event.tool ?? "").toLowerCase()
      if (!WATCHED_TOOLS.has(toolName)) return

      const text = extractText(event.result)
      const findings: string[] = []

      for (const [pattern, label] of PATTERNS) {
        if (pattern.test(text)) {
          findings.push(label)
        }
      }

      if (findings.length > 0) {
        const labels = findings.join(", ")
        process.stderr.write(
          `[secret-scan-output] WARNING — sensitive content detected in tool output: ${labels}.\n` +
          `  Do NOT echo these values back to the user, include them in conversation text,\n` +
          `  write them into documentation, or commit them to any repository.\n` +
          `  Reference resources by name or logical identifier only.\n`
        )
      }
    })
  },
})
