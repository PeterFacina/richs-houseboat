import { setTimeout as delay } from 'node:timers/promises';

export function studioClient(value) {
  const url = new URL(value);
  if (url.protocol !== 'http:' || url.hostname !== '127.0.0.1' || url.pathname !== '/'
      || url.search || url.hash || url.username || url.password) {
    throw new Error('STUDIO_URL must be a local HTTP origin using 127.0.0.1.');
  }
  async function call(path, signal, options) {
    const response = await fetch(new URL(path, url), { ...options, signal, redirect: 'error' });
    if (response.status === 409) throw new Error('Studio is busy. Try again after its current generation.');
    if (response.status === 422) throw new Error('Studio blocked the export. Review the prompt in Studio.');
    if (!response.ok) throw new Error('Studio returned HTTP ' + response.status + ' for ' + path);
    return response;
  }
  return async function generate(note) {
    const signal = AbortSignal.timeout(120_000);
    const session = await (await call('/api/session', signal)).json();
    if (session.privateMode || session.tailscaleMode || !session.user?.csrf) {
      throw new Error('The bot requires a separate loopback-mode Studio instance.');
    }
    const job = await (await call('/api/generate', signal, {
      method: 'POST',
      headers: { Origin: url.origin, 'Content-Type': 'application/json',
        'X-Studio-Request': '1', 'X-Studio-CSRF': session.user.csrf },
      body: JSON.stringify({ note, tier: 'detailed' }),
    })).json();
    for (;;) {
      await delay(750, undefined, { signal });
      const state = await (await call('/api/jobs/' + encodeURIComponent(job.id), signal)).json();
      if (state.status === 'complete') {
        return (await call('/api/prompts/' + state.recordId + '/download', signal)).text();
      }
      if (state.status !== 'working' && state.status !== 'canceling') {
        throw new Error('Studio generation ended with status ' + state.status + '.');
      }
    }
  };
}
