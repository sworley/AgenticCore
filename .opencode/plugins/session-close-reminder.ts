import { Plugin } from "@opencode/plugin";
import { execSync } from "child_process";

export default Plugin.define({
  id: "session-close-reminder",
  async setup(ctx) {
    await ctx.session.hook("prompt", () => {
      try {
        const worktrees = execSync("git worktree list --porcelain", {
          encoding: "utf-8",
        })
          .split("\n\n")
          .filter(Boolean);

        const dirty: string[] = [];
        for (const block of worktrees) {
          const pathMatch = block.match(/^worktree (.+)$/m);
          if (!pathMatch) continue;
          const wtPath = pathMatch[1];
          const status = execSync(`git -C "${wtPath}" status --short`, {
            encoding: "utf-8",
          }).trim();
          if (status) dirty.push(`${wtPath}: ${status.split("\n").length} uncommitted change(s)`);
        }

        if (dirty.length > 0) {
          process.stderr.write(
            `\n[session-close-reminder] Uncommitted changes detected:\n${dirty.map((d) => `  - ${d}`).join("\n")}\nRun session-close checklist before ending session.\n\n`
          );
        }
      } catch {
        // non-fatal — never interrupt agent work
      }
    });
  },
});
