import { join } from 'node:path';
import { existsSync, mkdirSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';

const DEFAULT_MAX_ITERATIONS = 25;
const DEFAULT_COMPACT_EVERY = 5;
const DEBOUNCE_MS = 1200;

function stateDir(directory) {
  return join(directory, '.opencode', 'loop');
}

function stateFile(directory) {
  return join(stateDir(directory), 'state.json');
}

function loadState(directory) {
  const file = stateFile(directory);
  if (!existsSync(file)) return null;
  try { return JSON.parse(readFileSync(file, 'utf-8')); } catch { return null; }
}

function saveState(directory, state) {
  const dir = stateDir(directory);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  writeFileSync(stateFile(directory), JSON.stringify(state, null, 2), 'utf-8');
}

function clearState(directory) {
  const file = stateFile(directory);
  if (existsSync(file)) unlinkSync(file);
}

export const LoopPlugin = async ({ client, $, directory, worktree }) => {
  let idleTimer = null;

  async function checkForDone(sessionId) {
    try {
      const messages = await client.session.messages({
        path: { id: sessionId },
        query: { directory },
      });
      const assistantMsgs = messages.filter(m => m.role === 'assistant');
      if (assistantMsgs.length === 0) return false;
      const last = assistantMsgs[assistantMsgs.length - 1];
      const text = (last.parts || [])
        .filter(p => p.type === 'text')
        .map(p => p.text)
        .join(' ');
      return /<promise>\s*DONE\s*<\/promise>/i.test(text);
    } catch { return false; }
  }

  async function compactSession(sessionId) {
    try {
      await client.tui.executeCommand({ command: 'session_compact' });
    } catch {
      try {
        await client.tui.executeCommand({ command: 'session.compact' });
      } catch {
        try {
          await client.session.summarize({ path: { id: sessionId }, body: {} });
        } catch {}
      }
    }
  }

  async function handleIdle(ev) {
    const state = loadState(directory);
    if (!state || !state.active || state.cancelled || state.completed) return;

    const sessionId = state.sessionId || ev?.sessionId;
    if (!sessionId) return;

    if (state.sessionId !== sessionId) {
      state.sessionId = sessionId;
      saveState(directory, state);
    }

    if (state.iteration >= state.maxIterations) {
      state.active = false;
      state.completed = true;
      state.endReason = 'max_iterations';
      saveState(directory, state);
      return;
    }

    const done = await checkForDone(sessionId);
    if (done) {
      state.active = false;
      state.completed = true;
      state.endReason = 'done';
      saveState(directory, state);
      return;
    }

    if (state.compactEvery > 0 &&
        (state.iteration - state.lastCompactIteration) >= state.compactEvery) {
      await compactSession(sessionId);
      state.lastCompactIteration = state.iteration;
      saveState(directory, state);
    }

    state.iteration++;
    state.lastRunAt = new Date().toISOString();
    saveState(directory, state);

    await client.session.prompt({
      path: { id: sessionId },
      body: {
        parts: [{
          type: 'text',
          text: `Continue working. Iteration ${state.iteration}/${state.maxIterations}. ` +
                `Make concrete progress. Output <promise>DONE</promise> only when fully complete.`,
        }],
      },
    });
  }

  return {
    'command.executed': async ({ event }) => {
      if (!event?.command) return;

      if (event.command === 'loop') {
        const input = event.input || event.args || event.prompt || '';
        const maxIterMatch = (typeof input === 'string') && input.match(/--max-iterations[= ](\d+)/i);
        const compactMatch = (typeof input === 'string') && input.match(/--compact-every[= ](\d+)/i);
        const maxIterations = maxIterMatch ? parseInt(maxIterMatch[1]) : DEFAULT_MAX_ITERATIONS;
        const compactEvery = compactMatch ? parseInt(compactMatch[1]) : DEFAULT_COMPACT_EVERY;

        saveState(directory, {
          active: true,
          prompt: typeof input === 'string' ? input : JSON.stringify(input),
          iteration: 1,
          maxIterations,
          compactEvery,
          sessionId: event.sessionId || null,
          startTime: new Date().toISOString(),
          lastRunAt: new Date().toISOString(),
          lastCompactIteration: 0,
          cancelled: false,
          completed: false,
        });
      }

      if (event.command === 'cancel-loop') {
        const state = loadState(directory);
        if (state?.active) {
          state.active = false;
          state.cancelled = true;
          saveState(directory, state);
        }
      }
    },

    'session.idle': async ({ event }) => {
      const state = loadState(directory);
      if (!state || !state.active || state.cancelled || state.completed) return;

      if (idleTimer) clearTimeout(idleTimer);
      idleTimer = setTimeout(() => handleIdle(event), DEBOUNCE_MS);
    },

    tool: {
      loop_complete: {
        description: 'Call when the loop task is fully finished and verified',
        args: {},
        execute: async () => {
          const state = loadState(directory);
          if (state?.active) {
            state.active = false;
            state.completed = true;
            saveState(directory, state);
          }
          return 'Loop marked complete.';
        },
      },

      loop_blocked: {
        description: 'Call when the loop task is blocked and cannot proceed',
        args: {
          reason: {
            description: 'Why the task is blocked',
            type: 'string',
          },
        },
        execute: async (args) => {
          const state = loadState(directory);
          if (state?.active) {
            state.active = false;
            state.completed = false;
            state.blockedReason = args?.reason || 'Unknown';
            saveState(directory, state);
          }
          return `Loop blocked: ${args?.reason || 'Unknown'}`;
        },
      },
    },

    'experimental.session.compacting': async (input, output) => {
      const state = loadState(directory);
      if (!state?.active) return;

      output.context.push(`## Active Loop State
You are in an autonomous dev loop (iteration ${state.iteration}/${state.maxIterations}).
Task: ${state.prompt}
Continue making progress. Output <promise>DONE</promise> only when fully complete.`);
    },
  };
};

export default LoopPlugin;
