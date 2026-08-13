import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { unlinkSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const { getDefaultMode, safeWriteFlag, readFlag } = require(join(here, 'caveman-config.cjs'));
const { parseModeChange, INDEPENDENT_MODES } = require(join(here, 'caveman-parse.cjs'));

function opencodeConfigDir() {
  return process.env.XDG_CONFIG_HOME ? path.join(process.env.XDG_CONFIG_HOME, 'opencode') : path.join(os.homedir(), '.config', 'opencode');
}

const flagPath = path.join(opencodeConfigDir(), '.caveman-active');

function removeFlag() {
  try { unlinkSync(flagPath); } catch (_) {}
}

function setMode(mode) {
  if (mode === 'off') removeFlag();
  else safeWriteFlag(flagPath, mode);
}

function applyModeChange(change) {
  if (!change) return;
  if (change.action === 'clear') removeFlag();
  if (change.action === 'set' && change.mode) setMode(change.mode);
}

function handleSessionCreated() {
  setMode(getDefaultMode());
}

export default async () => {
  handleSessionCreated();

  return {
    event: async ({ event } = {}) => {
      if (event && event.type === 'session.created') handleSessionCreated();
    },
    'chat.message': async (_input, output) => {
      if (!output || !output.parts) return;
      for (const part of output.parts) {
        if (part && part.type === 'text') {
          applyModeChange(parseModeChange(part.text, { getDefaultMode, unwrapQuotes: true }));
        }
      }
    },
    'experimental.chat.system.transform': async (_input, output) => {
      if (!output || !Array.isArray(output.system)) return;
      const active = readFlag(flagPath);
      if (active && !INDEPENDENT_MODES.has(active)) {
        output.system.push('CAVEMAN MODE ACTIVE - level: ' + active);
      }
    },
  };
};
