const fs = require('fs');
const path = require('path');
const os = require('os');

const VALID_MODES = ['off', 'lite', 'full', 'ultra', 'wenyan-lite', 'wenyan', 'wenyan-full', 'wenyan-ultra'];

function getConfigDir() {
  if (process.env.XDG_CONFIG_HOME) return path.join(process.env.XDG_CONFIG_HOME, 'caveman');
  return path.join(os.homedir(), '.config', 'caveman');
}

function readMode(file) {
  try {
    const config = JSON.parse(fs.readFileSync(file, 'utf8'));
    const mode = String(config.defaultMode || '').toLowerCase();
    return VALID_MODES.includes(mode) ? mode : null;
  } catch (_) {
    return null;
  }
}

function getDefaultMode() {
  const envMode = String(process.env.CAVEMAN_DEFAULT_MODE || '').toLowerCase();
  if (VALID_MODES.includes(envMode)) return envMode;
  return readMode(path.join(getConfigDir(), 'config.json')) || 'lite';
}

function safeWriteFlag(flagPath, content) {
  try {
    fs.mkdirSync(path.dirname(flagPath), { recursive: true });
    fs.writeFileSync(flagPath, String(content), { mode: 0o600 });
  } catch (_) {}
}

function readFlag(flagPath) {
  try {
    const mode = fs.readFileSync(flagPath, 'utf8').trim().toLowerCase();
    return VALID_MODES.includes(mode) ? mode : null;
  } catch (_) {
    return null;
  }
}

module.exports = { getDefaultMode, safeWriteFlag, readFlag, VALID_MODES };
