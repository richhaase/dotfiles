/**
 * Ralph Wiggum Loop Extension
 *
 * Runs a pi agent in a bash loop where each iteration gets a fresh context
 * window. An activity.md file serves as shared state between iterations.
 *
 * Commands:
 *   /ralph <prompt-file> [max-iterations]  — Start a Ralph loop
 *   /ralph-draft                           — Help draft a Ralph prompt
 *   /ralph-stop                            — Stop a running Ralph loop
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const ACTIVITY_FILE = "activity.md";

const DRAFT_PROMPT = `You are helping a user draft a prompt file for a Ralph Wiggum loop — an autonomous AI coding loop where each iteration gets a fresh context window.

A good Ralph prompt needs:

1. **Clear goal** — What is being built? One sentence.
2. **Task list** — Atomic, verifiable tasks. Each should be completable in one iteration (one context window). Format as a checklist:
   \`\`\`
   ## Tasks
   - [ ] Task 1 description
   - [ ] Task 2 description
   - [ ] Task 3 description
   \`\`\`
3. **Verification criteria** — How does the agent know a task is done? (build passes, tests pass, linter clean, etc.)
4. **Activity log instructions** — Tell the agent to read and append to activity.md.
5. **Constraints** — Language, framework, style, anything the agent should follow.

Ask the user what they want to build. Then draft a PROMPT.md file they can save and run with \`/ralph PROMPT.md\`.

Keep the prompt concise. Each task should be small enough for one context window. Order tasks so dependencies come first.

Start by asking: "What do you want to build?"`;

function ensureActivityFile(dir: string): string {
  const activityPath = path.join(dir, ACTIVITY_FILE);
  if (!fs.existsSync(activityPath)) {
    fs.writeFileSync(
      activityPath,
      "# Activity Log\n\nThis file tracks progress across Ralph loop iterations.\n\n"
    );
  }
  return activityPath;
}

let activeSession: { name: string; timer: ReturnType<typeof setInterval> } | null = null;

export default function ralph(pi: ExtensionAPI) {
  let _ui: ExtensionContext["ui"] | null = null;

  pi.on("session_start", async (_event, ctx) => {
    _ui = ctx.ui;
  });

  pi.on("session_shutdown", async () => {
    if (activeSession) {
      clearInterval(activeSession.timer);
      activeSession = null;
    }
  });

  // /ralph-draft — interactive prompt drafting
  pi.registerCommand("ralph-draft", {
    description: "Draft a Ralph Wiggum loop prompt interactively",
    handler: async (_args, _ctx) => {
      pi.sendUserMessage(DRAFT_PROMPT);
    },
  });

  // /ralph-stop — kill the running loop
  pi.registerCommand("ralph-stop", {
    description: "Stop a running Ralph loop",
    handler: async (_args, ctx) => {
      if (!activeSession) {
        ctx.ui.notify("No Ralph loop is running.", "warning");
        return;
      }
      clearInterval(activeSession.timer);
      await pi.exec("tmux", ["kill-session", "-t", activeSession.name], { timeout: 3000 }).catch(() => {});
      ctx.ui.setStatus("ralph", undefined);
      ctx.ui.notify(`Ralph loop '${activeSession.name}' stopped.`, "info");
      activeSession = null;
    },
  });

  // /ralph <prompt-file> [max-iterations] — run the loop
  pi.registerCommand("ralph", {
    description:
      "Start a Ralph Wiggum loop. Usage: /ralph <prompt-file> [max-iterations]",
    handler: async (args, ctx) => {
      _ui = ctx.ui;

      if (!args || !args.trim()) {
        ctx.ui.notify(
          "Usage: /ralph <prompt-file> [max-iterations]\n\nUse /ralph-draft to create a prompt file first.",
          "warning"
        );
        return;
      }

      const parts = args.trim().split(/\s+/);
      const promptFile = parts[0];
      const maxIterations = parseInt(parts[1] || "20", 10);

      // Resolve prompt file
      const promptPath = path.resolve(ctx.cwd, promptFile);
      if (!fs.existsSync(promptPath)) {
        ctx.ui.notify(`Prompt file not found: ${promptPath}`, "error");
        return;
      }

      const promptContent = fs.readFileSync(promptPath, "utf-8");
      ensureActivityFile(ctx.cwd);
      const ralphDir = path.join(ctx.cwd, ".ralph");

      if (!fs.existsSync(ralphDir)) {
        fs.mkdirSync(ralphDir, { recursive: true });
      }

      // Build the iteration prompt
      const iterationPrompt = `You are iteration $i of a Ralph Wiggum loop (max ${maxIterations}).

Read activity.md first to understand what previous iterations accomplished.

## Your Prompt

${promptContent}

## Instructions

1. Read ${ACTIVITY_FILE} to see what has been done
2. Find the next uncompleted task (marked with - [ ])
3. Complete it and verify it works
4. Mark it done in the prompt file (change - [ ] to - [x])
5. Append a brief log entry to ${ACTIVITY_FILE} with what you did
6. If all tasks are done, create a file called .ralph/DONE

Be autonomous. Do not ask questions. Do the work.`;

      // Write the bash loop script
      const scriptPath = path.join(ralphDir, "run.sh");
      const script = `#!/bin/bash
set -e

PROMPT_FILE='${promptPath.replace(/'/g, "'\\''")}'
MAX=${maxIterations}
OUTPUT_DIR='${ralphDir.replace(/'/g, "'\\''")}'

for i in $(seq 1 $MAX); do
  echo "=== Ralph iteration $i / $MAX ==="
  echo "=== Ralph iteration $i / $MAX ===" >> "$OUTPUT_DIR/log.txt"

  # Check if done
  if [ -f "$OUTPUT_DIR/DONE" ]; then
    echo "All tasks complete after $((i-1)) iterations."
    echo "All tasks complete after $((i-1)) iterations." >> "$OUTPUT_DIR/log.txt"
    exit 0
  fi

  # Run pi with fresh context
  pi --print '${iterationPrompt.replace(/'/g, "'\\''")}' 2>&1 | tee "$OUTPUT_DIR/iteration-$i.txt" >> "$OUTPUT_DIR/log.txt"

  echo "" >> "$OUTPUT_DIR/log.txt"
done

echo "Reached max iterations ($MAX) without completing all tasks."
echo "Reached max iterations ($MAX) without completing all tasks." >> "$OUTPUT_DIR/log.txt"
`;

      fs.writeFileSync(scriptPath, script, { mode: 0o755 });

      // Write wrapper so tmux session exits when the script finishes
      const wrapperPath = path.join(os.tmpdir(), `ralph-wrapper-${Date.now()}.sh`);
      fs.writeFileSync(
        wrapperPath,
        `#!/bin/bash\ncd ${ctx.cwd.replace(/'/g, "'\\''")}\nbash ${scriptPath} 2>&1 | tee ${ralphDir}/log.txt\n`,
        { mode: 0o755 }
      );

      const sessionName = `ralph-${Date.now()}`;
      const doneFile = path.join(ralphDir, "DONE");

      // Launch tmux with wrapper as the command (session dies when script exits)
      await pi.exec("tmux", ["kill-session", "-t", sessionName], { timeout: 3000 }).catch(() => {});
      await pi.exec("tmux", ["new-session", "-d", "-s", sessionName, wrapperPath], { timeout: 5000 });

      ctx.ui.setStatus("ralph", `🔄 Ralph running: ${sessionName}`);
      ctx.ui.notify(
        `Ralph loop started (${maxIterations} max iterations).\n` +
          `Watch: tmux attach -t ${sessionName}\n` +
          `Logs: ${ralphDir}/log.txt\n` +
          `Per-iteration: ${ralphDir}/iteration-N.txt`,
        "info"
      );

      // Poll for completion
      const pollInterval = setInterval(async () => {
        let alive = true;
        try {
          const r = await pi.exec("tmux", ["has-session", "-t", sessionName], { timeout: 3000 });
          alive = r.code === 0;
        } catch {
          alive = false;
        }

        if (!alive) {
          clearInterval(pollInterval);
          activeSession = null;

          const allDone = fs.existsSync(doneFile);
          if (_ui) {
            if (allDone) {
              _ui.setStatus("ralph", `✅ Ralph complete`);
              _ui.notify(`Ralph loop finished — all tasks complete.`, "info");
            } else {
              _ui.setStatus("ralph", `⚠️ Ralph exited`);
              _ui.notify(
                `Ralph loop exited without completing all tasks. Check: ${ralphDir}/log.txt`,
                "warning"
              );
            }
            setTimeout(() => _ui?.setStatus("ralph", undefined), 30_000);
          }
        }
      }, 30_000);

      activeSession = { name: sessionName, timer: pollInterval };
    },
  });
}
