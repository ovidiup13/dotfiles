const { VALID_MODES } = require('./caveman-config.cjs');

const INDEPENDENT_MODES = new Set();

function parseModeChange(promptRaw, options) {
  const getDefaultMode = (options && options.getDefaultMode) || (() => 'lite');
  const prompt = String(promptRaw || '').trim().toLowerCase().replace(/\s+/g, ' ');
  if (!prompt) return null;

  if (/\b(stop|disable|deactivate|quit|exit|kill)\s+(the\s+)?caveman\b/.test(prompt) ||
      /\bcaveman(\s+mode)?\s+(off|stop|disabled?)\b/.test(prompt) ||
      /\bturn\s+off\s+(the\s+)?caveman\b/.test(prompt) ||
      /^normal\s+mode\b/.test(prompt)) {
    return { action: 'clear' };
  }

  const command = /^\/caveman(?::caveman)?(?:\s+(\S+))?$/.exec(prompt);
  if (command) {
    const arg = command[1] || '';
    if (!arg) return { action: 'set', mode: getDefaultMode() };
    if (arg === 'off' || arg === 'stop' || arg === 'disable') return { action: 'clear' };
    if (VALID_MODES.includes(arg) && arg !== 'off') return { action: 'set', mode: arg };
    return null;
  }

  if (!/^(what|how|why|when|where|who|does|do|is|are|can|could|would|should)\b/.test(prompt) &&
      (/\b(activate|enable|start|turn on|use|switch to|want|give me)\b[^.]{0,40}\bcaveman\b/.test(prompt) ||
       /\btalk like\b[^.]{0,40}\bcaveman\b/.test(prompt) ||
       /\bcaveman\s+mode\s+(on|please|now)\b/.test(prompt) ||
       /^caveman(\s+mode)?[.!]*$/.test(prompt) ||
       /\b(less tokens|fewer tokens|be brief|be terse|shorter answers)\b/.test(prompt))) {
    return { action: 'set', mode: getDefaultMode() };
  }

  return null;
}

module.exports = { parseModeChange, INDEPENDENT_MODES };
