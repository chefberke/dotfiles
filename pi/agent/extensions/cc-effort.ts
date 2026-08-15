/**
 * cc-effort — a `/effort` command for the reasoning effort (thinking level).
 *
 * pi only offers a cycle key and the `/settings` menu for this. On macOS the
 * cycle key is awkward, so this adds a direct command:
 *
 *   /effort          open a picker with the levels the current model supports
 *   /effort high     set the level directly
 *
 * `pi.setThinkingLevel` clamps to what the model supports and emits
 * `thinking_level_select`, so the statusline follows without extra work.
 */

import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const ALL_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];
const CURRENT_MARK = "  (current)";

export default function (pi: ExtensionAPI) {
  function supportedLevels(ctx: ExtensionCommandContext): string[] {
    if (!ctx.model) return ALL_LEVELS;
    try {
      const levels = getSupportedThinkingLevels(ctx.model);
      return levels.length > 0 ? levels : ALL_LEVELS;
    } catch {
      return ALL_LEVELS;
    }
  }

  function apply(ctx: ExtensionCommandContext, level: string): void {
    pi.setThinkingLevel(level as never);
    const applied = pi.getThinkingLevel();
    if (applied === level) {
      ctx.ui.notify(`Effort: ${applied}`, "info");
    } else {
      ctx.ui.notify(`${ctx.model?.name ?? "This model"} has no "${level}" effort. Using ${applied}.`, "warning");
    }
  }

  pi.registerCommand("effort", {
    description: "Show or set the reasoning effort (thinking level)",

    getArgumentCompletions: (argumentPrefix) => {
      const prefix = argumentPrefix.trim().toLowerCase();
      if (/\s/.test(prefix)) return null;
      const matches = ALL_LEVELS.filter((level) => level.startsWith(prefix));
      return matches.length > 0 ? matches.map((level) => ({ value: level, label: level })) : null;
    },

    handler: async (args, ctx) => {
      const wanted = args.trim().toLowerCase();
      const current = pi.getThinkingLevel();

      if (wanted) {
        if (!ALL_LEVELS.includes(wanted)) {
          ctx.ui.notify(`Unknown effort "${wanted}". Use one of: ${ALL_LEVELS.join(", ")}.`, "error");
          return;
        }
        apply(ctx, wanted);
        return;
      }

      const levels = supportedLevels(ctx);
      if (levels.length <= 1) {
        ctx.ui.notify(`${ctx.model?.name ?? "This model"} has no reasoning effort levels.`, "info");
        return;
      }

      const choice = await ctx.ui.select(
        `Reasoning effort — now ${current}`,
        levels.map((level) => (level === current ? `${level}${CURRENT_MARK}` : level)),
      );
      if (!choice) return;
      apply(ctx, choice.replace(CURRENT_MARK, ""));
    },
  });
}
