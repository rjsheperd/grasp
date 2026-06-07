'use strict';

// ── Config ────────────────────────────────────────────────────────────────────

const CFG_KEY = 'grasp_config';

function loadConfig() {
  try { return JSON.parse(localStorage.getItem(CFG_KEY)); } catch { return null; }
}

function saveConfig(cfg) {
  localStorage.setItem(CFG_KEY, JSON.stringify(cfg));
}

// ── DOM refs ──────────────────────────────────────────────────────────────────

const captureScreen  = document.getElementById('capture-screen');
const settingsScreen = document.getElementById('settings-screen');
const form           = document.getElementById('capture-form');
const urlInput       = document.getElementById('url');
const titleInput     = document.getElementById('title');
const tagsInput      = document.getElementById('tags');
const commentInput   = document.getElementById('comment');
const submitBtn      = document.getElementById('submit-btn');
const settingsBtn    = document.getElementById('settings-btn');
const settingsForm   = document.getElementById('settings-form');
const endpointInput  = document.getElementById('endpoint');
const apiKeyInput    = document.getElementById('api-key');
const toast          = document.getElementById('toast');

// ── Toast ─────────────────────────────────────────────────────────────────────

let toastTimer;
function showToast(msg, type = 'info') {
  toast.textContent = msg;
  toast.className = `toast show ${type}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('show'), 3000);
}

// ── Screens ───────────────────────────────────────────────────────────────────

function showCapture() {
  captureScreen.classList.remove('hidden');
  settingsScreen.classList.add('hidden');
}

function showSettings() {
  captureScreen.classList.add('hidden');
  settingsScreen.classList.remove('hidden');
  const cfg = loadConfig();
  endpointInput.value = cfg?.endpoint ?? window.location.origin;
  apiKeyInput.value   = cfg?.apiKey   ?? '';
  endpointInput.focus();
}

// ── Settings form ─────────────────────────────────────────────────────────────

settingsForm.addEventListener('submit', e => {
  e.preventDefault();
  const cfg = {
    endpoint: endpointInput.value.replace(/\/$/, ''),
    apiKey:   apiKeyInput.value,
  };
  saveConfig(cfg);
  showToast('Settings saved', 'success');
  showCapture();
});

settingsBtn.addEventListener('click', showSettings);

// ── Capture form ──────────────────────────────────────────────────────────────

async function doCapture(payload, cfg) {
  const headers = { 'Content-Type': 'application/json' };
  if (cfg.apiKey) headers['Authorization'] = `Bearer ${cfg.apiKey}`;

  const r = await fetch(`${cfg.endpoint}/capture`, {
    method:  'POST',
    headers,
    body:    JSON.stringify(payload),
  });

  if (!r.ok) {
    const text = await r.text().catch(() => r.statusText);
    throw new Error(`${r.status} ${text}`);
  }
  return r.json();
}

form.addEventListener('submit', async e => {
  e.preventDefault();
  const cfg = loadConfig();
  if (!cfg) { showSettings(); return; }

  const payload = {
    url:       urlInput.value.trim(),
    title:     titleInput.value.trim(),
    selection: '',
    comment:   commentInput.value.trim(),
    tag_str:   tagsInput.value.trim(),
  };

  submitBtn.disabled = true;
  submitBtn.textContent = 'Capturing…';

  try {
    await doCapture(payload, cfg);
    showToast('Captured!', 'success');
    form.reset();
    // Auto-close when opened via share sheet (params in URL)
    if (window.location.search) {
      setTimeout(() => {
        if (!window.close()) window.history.back();
      }, 900);
    }
  } catch (err) {
    showToast(`Failed: ${err.message}`, 'error');
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = 'Capture';
  }
});

// ── Init ──────────────────────────────────────────────────────────────────────

function init() {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }

  const cfg = loadConfig();
  if (!cfg?.apiKey) {
    showSettings();
    return;
  }

  showCapture();

  // Pre-fill from Web Share Target GET params
  const p = new URLSearchParams(window.location.search);
  const sharedUrl   = p.get('url')   || p.get('text') || '';
  const sharedTitle = p.get('title') || '';
  if (sharedUrl)   { urlInput.value   = sharedUrl;   titleInput.focus(); }
  if (sharedTitle) { titleInput.value = sharedTitle; }
}

init();
