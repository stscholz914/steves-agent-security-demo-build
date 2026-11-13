const http = require('http');
const fs = require('fs');
const PORT = 8787;
const LOG = 'C:\\Demo\\tools\\stub.log';
const REPLY = 'Hello from the local demo stub. No real model is connected; this canned reply only shows that a normal prompt is not blocked.';
function log(s) { try { fs.appendFileSync(LOG, new Date().toISOString() + ' ' + s + '\n'); } catch (e) {} }

// Keyword router so Claude Code makes real MCP tool calls without a real model.
const ROUTES = [
  { re: /pii|ssn|export/i, tool: 'export_customer_pii', input: () => ({ count: 3 }) },
  { re: /balance/i, tool: 'get_account_balance', input: t => ({ accountId: (t.match(/ACC-\d+/i) || ['ACC-1001'])[0].toUpperCase() }) },
  { re: /account/i, tool: 'list_accounts', input: () => ({}) },
  { re: /health|uptime|status/i, tool: 'get_server_health', input: () => ({}) }
];
function textOf(c) {
  if (typeof c === 'string') return c;
  return (c || []).map(b => b.type === 'text' ? b.text : (b.type === 'tool_result' ? textOf(b.content) : '')).join('\n');
}
// Claude Code can resend old tool_results alongside a new prompt, so only unanswered results from tool calls issued here count.
const issued = new Set();
const answered = new Set();
function plan(j) {
  const msgs = j.messages || [];
  const last = msgs[msgs.length - 1];
  if (!last || last.role !== 'user') return { text: REPLY };
  const blocks = Array.isArray(last.content) ? last.content : [{ type: 'text', text: textOf(last.content) }];
  const fresh = blocks.filter(b => b.type === 'tool_result' && issued.has(b.tool_use_id) && !answered.has(b.tool_use_id));
  if (fresh.length) {
    fresh.forEach(b => answered.add(b.tool_use_id));
    const isErr = fresh.some(b => b.is_error);
    const out = fresh.map(b => textOf(b.content)).join(' ').replace(/\s+/g, ' ').slice(0, 400);
    return { text: (isErr ? 'The MCP tool call was refused or failed: ' : 'The MCP tool returned: ') + out };
  }
  const names = (j.tools || []).map(t => t.name);
  const texts = blocks.filter(b => b.type === 'text' && !/^\s*<system-reminder>/.test(b.text)).map(b => b.text);
  const prompt = texts.length ? texts[texts.length - 1] : '';
  for (const r of ROUTES) {
    if (!r.re.test(prompt)) continue;
    const name = names.find(n => n.startsWith('mcp__') && n.endsWith('__' + r.tool));
    if (name) {
      const id = 'toolu_stub' + Date.now();
      issued.add(id);
      return { tool: { id, name, input: r.input(prompt) } };
    }
  }
  return { text: REPLY };
}function sse(res, model, p) {
  res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache', connection: 'keep-alive' });
  const ev = (n, d) => res.write('event: ' + n + '\ndata: ' + JSON.stringify(d) + '\n\n');
  ev('message_start', { type: 'message_start', message: { id: 'msg_stub', type: 'message', role: 'assistant', model, content: [], stop_reason: null, stop_sequence: null, usage: { input_tokens: 10, output_tokens: 1 } } });
  if (p.tool) {
    ev('content_block_start', { type: 'content_block_start', index: 0, content_block: { type: 'tool_use', id: p.tool.id, name: p.tool.name, input: {} } });
    ev('content_block_delta', { type: 'content_block_delta', index: 0, delta: { type: 'input_json_delta', partial_json: JSON.stringify(p.tool.input) } });
    ev('content_block_stop', { type: 'content_block_stop', index: 0 });
    ev('message_delta', { type: 'message_delta', delta: { stop_reason: 'tool_use', stop_sequence: null }, usage: { output_tokens: 28 } });
  } else {
    ev('content_block_start', { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } });
    ev('ping', { type: 'ping' });
    ev('content_block_delta', { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: p.text } });
    ev('content_block_stop', { type: 'content_block_stop', index: 0 });
    ev('message_delta', { type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: null }, usage: { output_tokens: 28 } });
  }
  ev('message_stop', { type: 'message_stop' });
  res.end();
}
http.createServer((req, res) => {
  let body = '';
  req.on('data', c => body += c);
  req.on('end', () => {
    const path = req.url.split('?')[0].replace(/^\/anthropic/, '');
    log(req.method + ' ' + req.url);
    if (req.method === 'POST' && path === '/v1/messages') {
      let j = {}; try { j = JSON.parse(body); } catch (e) {}
      const model = j.model || 'claude-demo-stub';
      const p = plan(j);
      if (p.tool) log('tool_use -> ' + p.tool.name + ' ' + JSON.stringify(p.tool.input));
      if (j.stream) return sse(res, model, p);
      res.writeHead(200, { 'content-type': 'application/json' });
      const content = p.tool ? [{ type: 'tool_use', id: p.tool.id, name: p.tool.name, input: p.tool.input }] : [{ type: 'text', text: p.text }];
      return res.end(JSON.stringify({ id: 'msg_stub', type: 'message', role: 'assistant', model, content, stop_reason: p.tool ? 'tool_use' : 'end_turn', stop_sequence: null, usage: { input_tokens: 10, output_tokens: 28 } }));
    }
    if (path.endsWith('/count_tokens')) { res.writeHead(200, { 'content-type': 'application/json' }); return res.end(JSON.stringify({ input_tokens: 10 })); }
    res.writeHead(404, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ type: 'error', error: { type: 'not_found_error', message: 'demo stub: no such route' } }));
  });
}).listen(PORT, '127.0.0.1', () => log('stub listening on ' + PORT));
