const http = require('http');
const fs = require('fs');
const PORT = 8787;
const LOG = 'C:\\Demo\\tools\\stub.log';
const REPLY = 'Hello from the local demo stub. No real model is connected; this canned reply only shows that a normal prompt is not blocked.';
function log(s) { try { fs.appendFileSync(LOG, new Date().toISOString() + ' ' + s + '\n'); } catch (e) {} }
function sse(res, model) {
  res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache', connection: 'keep-alive' });
  const ev = (n, d) => res.write('event: ' + n + '\ndata: ' + JSON.stringify(d) + '\n\n');
  ev('message_start', { type: 'message_start', message: { id: 'msg_stub', type: 'message', role: 'assistant', model, content: [], stop_reason: null, stop_sequence: null, usage: { input_tokens: 10, output_tokens: 1 } } });
  ev('content_block_start', { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } });
  ev('ping', { type: 'ping' });
  ev('content_block_delta', { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: REPLY } });
  ev('content_block_stop', { type: 'content_block_stop', index: 0 });
  ev('message_delta', { type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: null }, usage: { output_tokens: 28 } });
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
      if (j.stream) return sse(res, model);
      res.writeHead(200, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ id: 'msg_stub', type: 'message', role: 'assistant', model, content: [{ type: 'text', text: REPLY }], stop_reason: 'end_turn', stop_sequence: null, usage: { input_tokens: 10, output_tokens: 28 } }));
    }
    if (path.endsWith('/count_tokens')) { res.writeHead(200, { 'content-type': 'application/json' }); return res.end(JSON.stringify({ input_tokens: 10 })); }
    res.writeHead(404, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ type: 'error', error: { type: 'not_found_error', message: 'demo stub: no such route' } }));
  });
}).listen(PORT, '127.0.0.1', () => log('stub listening on ' + PORT));
