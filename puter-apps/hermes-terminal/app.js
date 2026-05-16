(function() {
  'use strict';

  const API_URL = 'https://privseai.com/ai/code-assist';
  const HEALTH_URL = 'https://privseai.com/health';
  const MODEL = 'claude-sonnet-4';

  const state = {
    mode: 'auto',
    messages: [],
    verifyEnabled: true,
    sending: false,
  };

  const els = {
    messages: document.getElementById('messages'),
    input: document.getElementById('input'),
    sendBtn: document.getElementById('send-btn'),
    modeBtns: document.querySelectorAll('.mode-btn'),
    verifyToggle: document.getElementById('verify-toggle'),
    clearBtn: document.getElementById('clear-btn'),
  };

  els.sendBtn.addEventListener('click', send);
  els.input.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      send();
    }
    updateSendButton();
  });
  els.input.addEventListener('input', updateSendButton);

  els.modeBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      els.modeBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.mode = btn.dataset.mode;
    });
  });

  els.verifyToggle.addEventListener('change', () => {
    state.verifyEnabled = els.verifyToggle.checked;
  });

  els.clearBtn.addEventListener('click', () => {
    state.messages = [];
    els.messages.innerHTML = '';
    addSystemMessage('Chat cleared.');
  });

  addSystemMessage('Hermes ready. Select a mode and ask anything.');

  checkHealth();

  function updateSendButton() {
    els.sendBtn.disabled = !els.input.value.trim() || state.sending;
  }

  function addSystemMessage(text) {
    addMessage({ role: 'system', content: text });
  }

  function addMessage(msg) {
    state.messages.push(msg);
    renderMessage(msg);
    scrollToBottom();
  }

  function renderMessage(msg) {
    const div = document.createElement('div');
    div.className = `msg msg-${msg.role}`;

    const avatar = document.createElement('div');
    avatar.className = 'msg-avatar';
    avatar.textContent = msg.role === 'user' ? 'U' : '🤖';

    const body = document.createElement('div');
    body.className = 'msg-body';

    const header = document.createElement('div');
    header.className = 'msg-header';
    header.textContent = msg.role === 'user' ? 'You' : msg.label || 'Hermes';

    const content = document.createElement('div');
    content.className = 'msg-content';
    content.innerHTML = renderContent(msg.content);

    body.appendChild(header);
    body.appendChild(content);

    if (msg.meta) {
      const meta = document.createElement('div');
      meta.className = 'msg-meta';
      meta.textContent = msg.meta;
      body.appendChild(meta);
    }

    div.appendChild(avatar);
    div.appendChild(body);
    els.messages.appendChild(div);
  }

  function renderContent(text) {
    if (!text) return '';
    const escaped = text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');

    const withCode = escaped.replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, code) => {
      const langClass = lang ? ` class="lang-${lang}"` : '';
      return `<pre${langClass}><code>${code.trim()}</code></pre>`;
    });

    const withInline = withCode.replace(/`([^`]+)`/g, '<code>$1</code>');

    const withBold = withInline.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    const withLines = withBold.replace(/\n/g, '<br>');

    return withLines;
  }

  function scrollToBottom() {
    requestAnimationFrame(() => {
      els.messages.scrollTop = els.messages.scrollHeight;
    });
  }

  function showTyping() {
    const div = document.createElement('div');
    div.className = 'msg msg-assistant typing-indicator';
    div.id = 'typing-indicator';
    div.innerHTML = '<div class="typing-dots"><span></span><span></span><span></span></div>';
    els.messages.appendChild(div);
    scrollToBottom();
  }

  function hideTyping() {
    const el = document.getElementById('typing-indicator');
    if (el) el.remove();
  }

  async function send() {
    const text = els.input.value.trim();
    if (!text || state.sending) return;

    state.sending = true;
    updateSendButton();
    els.input.value = '';
    els.input.style.height = 'auto';

    addMessage({ role: 'user', content: text });

    showTyping();

    try {
      const body = {
        messages: [{ role: 'user', content: text }],
        mode: state.mode,
      };
      if (state.mode !== 'normal' && state.verifyEnabled) {
        body.use_verification = true;
      }

      const startTime = performance.now();
      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const elapsed = ((performance.now() - startTime) / 1000).toFixed(1);

      hideTyping();

      if (!res.ok) {
        const errText = await res.text().catch(() => 'Unknown error');
        addMessage({
          role: 'assistant',
          content: `Error ${res.status}: ${errText}`,
          label: 'Hermes Error',
        });
        return;
      }

      const data = await res.json();
      const reply = data.reply || data.result || '(no response)';
      const source = data.source || data.provider || 'opencode';
      const respMode = data.mode || state.mode;

      addMessage({
        role: 'assistant',
        content: reply,
        label: `Hermes [${respMode}]`,
        meta: `${elapsed}s · ${source} · ${MODEL}`,
      });

    } catch (err) {
      hideTyping();
      addMessage({
        role: 'assistant',
        content: `Network error: ${err.message}. Check your connection and try again.`,
        label: 'Hermes Error',
      });
    } finally {
      state.sending = false;
      updateSendButton();
    }
  }

  async function checkHealth() {
    try {
      const res = await fetch(HEALTH_URL);
      const data = await res.json();
      const ollamaDot = document.querySelector('.dot.yellow');
      const ollamaText = ollamaDot?.parentElement;
      if (data.status === 'healthy') {
        if (ollamaText) {
          const ok = data.localai === 'up';
          ollamaDot.className = `dot ${ok ? 'green' : 'yellow'}`;
          ollamaText.innerHTML = `<span class="dot ${ok ? 'green' : 'yellow'}"></span>Ollama: ${ok ? 'Ready' : 'Down (normal)'}`;
        }
      }
    } catch {
      // health check is best-effort
    }
  }
})();
