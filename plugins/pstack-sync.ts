import { tool, type Plugin } from "@opencode-ai/plugin"

// Thin wrapper: all sync logic lives in scripts/sync-pstack.sh,
// which is the single source of truth. This file only exposes it
// as an in-opencode tool so agents can run it on request.

const SCRIPT = `${process.env.HOME}/.config/opencode/scripts/sync-pstack.sh`

export const PstackSyncPlugin: Plugin = async ({ $ }) => {
  return {
    tool: {
      pstack_sync: tool({
        description:
          "Sync pstack skills/agents from the cursor/plugins checkout into opencode. Pulls latest, copies new/changed skills with opencode model/path transforms, keeps opencode-only customizations. Use when the user asks to sync, update, or refresh pstack.",
        args: {
          dry_run: tool.schema.boolean().optional().describe("Preview changes without writing"),
          no_pull: tool.schema.boolean().optional().describe("Skip git pull, sync from local checkout only"),
        },
        async execute(args) {
          const flags = [args.dry_run ? "--dry-run" : "", args.no_pull ? "--no-pull" : ""]
            .filter(Boolean)
            .join(" ")
          const proc = await $`${SCRIPT} ${flags}`.nothrow().quiet()
          const out = [String(proc.stdout ?? ""), String(proc.stderr ?? "")]
            .map((s) => s.trim())
            .filter(Boolean)
            .join("\n")
          if (proc.exitCode !== 0) throw new Error(out || "pstack sync failed")
          return out || "pstack sync complete"
        },
      }),
    },
  }
}
