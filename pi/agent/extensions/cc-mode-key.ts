/**
 * cc-mode-key — make shift+tab toggle Plan mode, like Claude Code.
 *
 * pi binds shift+tab to `app.thinking.cycle`. `~/.pi/agent/keybindings.json`
 * moves that action to alt+t, which frees shift+tab for this shortcut.
 *
 * One press enters Plan mode, the next press leaves it. No menu. The current
 * state is read from the active tool list rather than from a local flag, so the
 * toggle stays correct even when Plan mode is started or ended some other way:
 * @narumitw/pi-plan-mode adds `plan_mode_complete` to the active tools while
 * Plan mode runs and removes it on exit. Use `/plan` for the full menu.
 *
 * Note on the submit: pi gives extensions `setEditorText` but no way to submit
 * the editor, and `pi.sendUserMessage` goes straight to the model without slash
 * command resolution. So this writes the command into the editor and feeds a
 * carriage return to the TUI's own stdin listener — the same path a real Enter
 * key takes. If a pi release ever adds a submit API, replace this.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const SHORTCUT = "shift+tab";
const PLAN_MODE_TOOL = "plan_mode_complete";
const START_COMMAND = "/plan start";
const EXIT_COMMAND = "/plan exit";
const DRAFT_RESTORE_MS = 80;

function submitCommand(ctx: ExtensionContext, command: string): void {
  const draft = ctx.ui.getEditorText();

  // Defer: the handler runs inside the TUI's own stdin dispatch.
  setTimeout(() => {
    ctx.ui.setEditorText(command);
    process.stdin.emit("data", Buffer.from("\r"));
    if (draft) {
      setTimeout(() => ctx.ui.setEditorText(draft), DRAFT_RESTORE_MS);
    }
  }, 0);
}

export default function (pi: ExtensionAPI) {
  function planModeActive(): boolean {
    try {
      return pi.getActiveTools().includes(PLAN_MODE_TOOL);
    } catch {
      return false;
    }
  }

  pi.registerShortcut(SHORTCUT, {
    description: "Toggle Plan mode",
    handler: (ctx) => {
      if (ctx.mode !== "tui" || !ctx.hasUI) return;
      submitCommand(ctx, planModeActive() ? EXIT_COMMAND : START_COMMAND);
    },
  });
}
