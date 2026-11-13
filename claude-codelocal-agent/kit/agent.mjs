#!/usr/bin/env node
/*
 * Dependency-free MCP demo agent (Node 18+).
 *   node agent.mjs                                   direct URL (set MCP_URL or edit DIRECT below)
 *   node agent.mjs --url https://other/mcp           another endpoint
 *   node agent.mjs --url <A> --url <B>               run both and compare
 *   node agent.mjs --tool get_account_balance --args '{"accountId":"ACC-1001"}'
 */

const DIRECT = process.env.MCP_URL || "https://<APP_NAME>.azurewebsites.net/mcp";

const argv = process.argv.slice(2);
const urls = [];
let single = null, singleArgs = {};
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === "--url") urls.push(argv[++i]);
  else if (argv[i] === "--tool") single = argv[++i];
  else if (argv[i] === "--args") singleArgs = JSON.parse(argv[++i]);
}
if (!urls.length) urls.push(DIRECT);

const C = {
  r: "\x1b[0m", dim: "\x1b[90m", b: "\x1b[1m",
  grn: "\x1b[32m", red: "\x1b[31m", yel: "\x1b[33m", cyn: "\x1b[36m"
};

let nextId = 1;

async function rpc(url, method, params) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Accept": "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", id: nextId++, method, params })
  });
  const raw = await res.text();
  const sse = raw.match(/^data:\s*(.+)$/m);
  let json = null;
  try { json = JSON.parse(sse ? sse[1] : raw); } catch { /* non-JSON body */ }
  return { status: res.status, json, raw };
}

async function callTool(url, name, args) {
  process.stdout.write("\n" + C.cyn + "-> " + name + C.r + " " + C.dim + JSON.stringify(args) + C.r + "\n");
  let r;
  try {
    r = await rpc(url, "tools/call", { name, arguments: args });
  } catch (e) {
    console.log("   " + C.red + "NETWORK FAILURE" + C.r + " " + e.message);
    if (/certificate|self.signed|UNABLE_TO_VERIFY/i.test(e.message)) {
      console.log("   " + C.yel + "TLS trust problem - set NODE_EXTRA_CA_CERTS to the inspection CA." + C.r);
    }
    return "error";
  }
  if (r.status === 403) {
    console.log("   " + C.red + C.b + "BLOCKED" + C.r + C.red + "  (HTTP 403 - refused in-network)" + C.r);
    return "blocked";
  }
  if (r.status >= 400 || !r.json) {
    console.log("   " + C.yel + "UNEXPECTED (HTTP " + r.status + ")" + C.r);
    return "error";
  }
  if (r.json.error) {
    if (/blocked by/i.test(r.json.error.message || "")) {
      console.log("   " + C.red + C.b + "BLOCKED" + C.r + C.red + "  (" + r.json.error.message.split(/\r?\n/)[0] + ")" + C.r);
      if (r.json.error.data?.connectionId) console.log("   " + C.dim + "connection id: " + r.json.error.data.connectionId + C.r);
      return "blocked";
    }
    console.log("   " + C.yel + "MCP ERROR " + JSON.stringify(r.json.error) + C.r);
    return "error";
  }
  const text = (r.json.result?.content ?? []).map(c => c.text).join("\n");
  console.log("   " + C.grn + "ALLOWED" + C.r + C.dim + "  (HTTP 200)" + C.r);
  console.log(text.split("\n").map(l => "   " + C.dim + l + C.r).join("\n"));
  return "allowed";
}

async function run(url) {
  console.log("\n" + C.b + "MCP demo agent" + C.r);
  console.log(C.dim + "endpoint: " + url + C.r);
  const init = await rpc(url, "initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "mcp-demo-agent", version: "1.0.0" }
  });
  if (init.status !== 200) {
    console.log(C.red + "initialize failed: HTTP " + init.status + C.r);
    return null;
  }
  console.log(C.grn + "connected" + C.r);
  const list = await rpc(url, "tools/list", {});
  const tools = list.json?.result?.tools ?? [];
  console.log(C.dim + "discovered " + tools.length + " tools: " + tools.map(t => t.name).join(", ") + C.r);

  const plan = single
    ? [[single, singleArgs]]
    : [["get_server_health", {}], ["list_accounts", {}],
       ["get_account_balance", { accountId: "ACC-1001" }], ["export_customer_pii", { count: 3 }]];
  const out = {};
  for (const [n, a] of plan) out[n] = await callTool(url, n, a);
  return out;
}

const results = {};
for (const u of urls) results[u] = await run(u).catch(e => { console.log(C.red + "fatal: " + e.message + C.r); return null; });

if (urls.length > 1) {
  console.log("\n" + C.b + "Summary" + C.r);
  for (const u of urls) console.log(C.dim + u + C.r + "\n   " + JSON.stringify(results[u]));
}
console.log();
