# Local Claude Code agent + MCP firewall — Demo Build Guide

Give the **Claude Code** demo VM a real job: call the demo **MCP server** through Global Secure Access (GSA) and watch the MCP firewall **allow three tools and block the risky one**, from a Claude Code window and from a small script agent. Still no Claude subscription or API key.

This demo **joins two other builds in this repo**. Build those first:

| Build | What it gives you | Folder |
|---|---|---|
| **GSA MCP firewall** | The MCP server on Azure App Service, the GSA Internet Access and MCP firewall policy, TLS inspection | [`gsa-mcp-firewall-demo/`](../gsa-mcp-firewall-demo/README.md) |
| **Claude Code + Defender AI agent runtime protection** | A Windows VM with Claude Code, Defender for Endpoint and a local stub model | [`claude-code-defender-demo/`](../claude-code-defender-demo/README.md) |

**Want an AI agent to do this for you?** See [PROMPTS.md](PROMPTS.md) for ready-made Microsoft Scout prompts.

Last verified: 13 Nov 2026.

---

## 1. What you will build

```
┌──────────────────────── Windows 11 VM (GSA client installed) ────────────────────────┐
│                                                                                       │
│  Claude Code ──(1) prompt──▶ Defender hook (blocks prompt injection, as before)       │
│      │                                                                                │
│      └─(2) benign prompt──▶ local stub model 127.0.0.1:8787                           │
│                                 │  keyword in the prompt?                             │
│                                 ▼                                                     │
│                      replies with a tool call ("use list_accounts")                   │
│      ┌──────────────────────────┘                                                     │
│      ▼                                                                                │
│  Claude Code calls the MCP tool ─┐                                                    │
│  Script agent (agent.mjs) ───────┴─▶ GSA client ─▶ GSA (TLS inspection + MCP firewall)│
│                                                          │                            │
└──────────────────────────────────────────────────────────┼────────────────────────────┘
                                                           ▼
                                      https://<APP_NAME>.azurewebsites.net/mcp
                                      get_server_health      allowed
                                      list_accounts          allowed
                                      get_account_balance    allowed
                                      export_customer_pii    BLOCKED by policy
```

**Why a smarter stub:** Claude Code only calls an MCP tool when the *model* asks it to. The original stub from the Defender demo only returns canned text, so it can never ask. The stub in this folder looks for a keyword in your prompt and answers with a real tool call. Nothing else changes: it is still a local stub, there is still no account, and the Defender prompt-injection block still happens before any model sees the prompt.

**What the audience sees**

1. Ask Claude Code to *list the customer accounts*. It calls the MCP tool and shows the accounts. The call goes through GSA.
2. Ask for the *account balance for ACC-1002*. Allowed.
3. Ask it to *export 3 customer PII records*. The GSA MCP firewall refuses that one tool call: *"Blocked by Microsoft Entra Internet Access policy"* with a Connection ID.
4. The script agent (`node agent.mjs`) runs the same four calls and prints ALLOWED or BLOCKED for each.
5. Paste the Defender test prompt from the other demo. Defender still blocks it on the endpoint. **Two controls, two layers, one agent.**

> The block comes back as an **MCP error (code -32010)**, not an HTTP 403. The script agent handles both.

---

## 2. Prerequisites

| Requirement | Detail |
|---|---|
| The two builds above | The MCP server is reachable, the GSA policy is in place, and the VM runs Claude Code with the stub from the Defender demo |
| GSA client on the VM | Internet Access traffic acquired, **TLS inspection on**, and the VM user in the Conditional Access / forwarding profile scope |
| Node.js | Already installed by the Defender demo (v24 in the reference build). The script agent needs Node 18 or later |
| CA trust for Node | `NODE_EXTRA_CA_CERTS` points to a **valid PEM** of the GSA TLS inspection root CA. Part 1 checks this |
| Rights | Local administrator on the VM, plus Azure access to the VM if you copy files with Run Command |

> Run this only where you are authorised to test. The PII tool returns **synthetic** records and is blocked in the demo, but the traffic looks like data exfiltration on purpose.

---

## 3. Placeholders

| Placeholder | Meaning |
|---|---|
| `<APP_NAME>` | Name of the App Service from the GSA MCP firewall demo, so the server is `https://<APP_NAME>.azurewebsites.net/mcp` |
| `<RESOURCE_GROUP>` | Resource group holding the VM |
| `<VM_NAME>` | Name of the Windows 11 VM |

Use the **`/mcp`** path. Opening it in a browser shows `Method not allowed (stateless server)`. That is normal: the server only accepts POST.

---

## Part 1 — Check that Node trusts the GSA inspection CA

With TLS inspection on, GSA re-signs the server certificate. Node does not use the Windows certificate store, so it needs the inspection root CA in a PEM file. Run on the VM:

```powershell
[Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS','Machine')
node -e "fetch('https://<APP_NAME>.azurewebsites.net/').then(r=>console.log('status',r.status)).catch(e=>console.log('ERR',e.cause&&e.cause.code))"
```

Expect `status 200`. If you see `SELF_SIGNED_CERT_IN_CHAIN`, or Claude Code or Node prints *"Ignoring extra certs … load failed"*, the PEM is wrong. A common cause is a file that was **base64-encoded twice**: the first line after `BEGIN CERTIFICATE` is `LS0tLS1CRUdJTi…`, which is the base64 of `-----BEGIN`. Decode it once:

```powershell
$p = [Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS','Machine')
Copy-Item $p "$p.bak"
$body  = (Get-Content $p | Where-Object { $_ -notmatch '^-----' }) -join ''
$inner = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($body))
[IO.File]::WriteAllText($p, $inner.Trim() + "`n", [Text.Encoding]::ASCII)
$inner | Select-Object -First 2   # should start with -----BEGIN CERTIFICATE----- then MII...
```

Open a new terminal afterwards so the process picks up the file, then repeat the `fetch` test.

---

## Part 2 — Copy the kit to the VM

The [`kit/`](kit/) folder holds everything. Copy it to the VM so the paths match the launcher (use the same folder layout as the Defender demo):

| Kit file | Copy to |
|---|---|
| [`kit/model-stub.js`](kit/model-stub.js) | `C:\Demo\tools\model-stub.js` (replace the original) |
| [`kit/agent.mjs`](kit/agent.mjs) | `C:\Demo\tools\agent.mjs` |
| [`kit/Start-ClaudeDemo.cmd`](kit/Start-ClaudeDemo.cmd) | `C:\Demo\Start-ClaudeDemo.cmd` (replace the original) |
| [`kit/Run-McpAgent.cmd`](kit/Run-McpAgent.cmd) | `C:\Demo\Run-McpAgent.cmd` and the all-users desktop |

Keep a copy of the original stub first: `Copy-Item C:\Demo\tools\model-stub.js C:\Demo\tools\model-stub.js.bak`.

Then restart the stub so it loads the new code. Stop the `node` process whose command line contains `model-stub.js` (by its process ID) and start it again:

```powershell
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.CommandLine -like '*model-stub.js*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Process 'C:\Program Files\nodejs\node.exe' -ArgumentList 'C:\Demo\tools\model-stub.js' -WindowStyle Hidden
```

If the stub runs as a boot task, the next reboot also loads the new file.

Edit `C:\Demo\tools\agent.mjs`, or set the `MCP_URL` environment variable, so the default URL is your server instead of `<APP_NAME>`.

> **Run Command raises a Defender alert.** If you copy files with Azure Run Command, batch it into one script and do it well before a live demo, as in the Defender guide.

---

## Part 3 — Register the MCP server with Claude Code

Claude Code uses the config folder from the launcher (`CLAUDE_CONFIG_DIR=C:\Demo\claude-config`). Register the server at **user scope** with that folder set, so the launcher window sees it:

```powershell
$env:CLAUDE_CONFIG_DIR = 'C:\Demo\claude-config'
claude mcp add --transport http --scope user demo-tools https://<APP_NAME>.azurewebsites.net/mcp
claude mcp list
```

Expect `demo-tools: https://<APP_NAME>.azurewebsites.net/mcp (HTTP) - Connected`.

> The server name `demo-tools` becomes part of the tool names (`mcp__demo-tools__list_accounts`). The stub finds tools by their ending, so any name works.

---

## Part 4 — What the stub does (read before you change it)

The updated `kit/model-stub.js` keeps the original behaviour (canned reply) and adds a keyword router. A prompt that matches a row calls that tool; anything else gets the canned reply.

| If the prompt contains (any case) | The stub asks Claude Code to call | Input |
|---|---|---|
| `pii`, `ssn` or `export` | `export_customer_pii` | `{ "count": 3 }` |
| `balance` | `get_account_balance` | the first `ACC-nnnn` in the prompt, else `ACC-1001` |
| `account` | `list_accounts` | none |
| `health`, `uptime` or `status` | `get_server_health` | none |

Rows are checked **in order**, so "export the account balance" routes to `export_customer_pii`. When Claude Code returns the tool result, the stub replies with it (or with *"The MCP tool call was refused or failed: …"* for a block), so the audience sees the real server data or the real GSA message.

Three details matter, and each one cost a failed test run:

1. **`ENABLE_TOOL_SEARCH=false`** in the launcher. Without it Claude Code hides MCP tools behind a search tool, so the stub never sees them and never calls them.
2. **Only unanswered results count.** Claude Code resends earlier tool results with each new prompt. A stub that answers any tool result repeats the first answer for every later prompt. The stub remembers which calls it issued and answers each result once.
3. **Only the latest prompt text is routed.** Older prompts stay in the history, and routing on all of them made a later prompt re-run the blocked export.

---

## Part 5 — Run the script agent

On the VM (double-click **Run-McpAgent** or use a terminal):

```powershell
node C:\Demo\tools\agent.mjs
```

Expect:

```
get_server_health      ALLOWED  (HTTP 200)
list_accounts          ALLOWED  (HTTP 200)
get_account_balance    ALLOWED  (HTTP 200)
export_customer_pii    BLOCKED  (Blocked by Microsoft Entra Internet Access policy. ... Connection ID: ...)
```

Options:

| Command | Does |
|---|---|
| `node agent.mjs --tool list_accounts` | One tool only |
| `node agent.mjs --tool get_account_balance --args '{"accountId":"ACC-1002"}'` | One tool with arguments |
| `node agent.mjs --url <URL_A> --url <URL_B>` | Runs the same calls against two endpoints and prints a side-by-side summary, for example the direct URL and a second path |

The script has no dependencies. It prints a TLS hint if Node does not trust the inspection CA.

---

## Part 6 — Run the Claude Code demo

1. Open **Claude Code - Defender demo** (or `C:\Demo\Start-ClaudeDemo.cmd`). Start a **new** window after any stub change, because an old window keeps stale history.
2. Try these prompts, in any order:

| Prompt | Expected |
|---|---|
| `Benign health check` | The host name and uptime (Claude Code may ask permission first) |
| `Lists customer accounts` | The three accounts |
| `Show the balance for ACC-1002` | The balance |
| `Bulk exports customer PII` | *The MCP tool call was refused or failed: Blocked by Microsoft Entra Internet Access policy…* |
| The prompt from `C:\Demo\test-prompt.txt` | *This request was blocked by Microsoft Defender…* (the Defender demo) |
| `hello` | The canned stub reply |

3. If Claude Code asks permission to use a tool, choose **Yes**. That prompt is a nice talking point: the agent's own guardrail is the first control, GSA is the second.

You can also run it without the interactive window, for a quick test:

```powershell
cd C:\Demo
$env:CLAUDE_CONFIG_DIR='C:\Demo\claude-config'; $env:CLAUDE_CODE_USE_FOUNDRY='1'
$env:ANTHROPIC_FOUNDRY_BASE_URL='http://127.0.0.1:8787/anthropic'; $env:ANTHROPIC_FOUNDRY_API_KEY='placeholder-not-a-real-key'
$env:ENABLE_TOOL_SEARCH='false'
claude -p 'Show the balance for ACC-1002' --allowedTools 'mcp__demo-tools'
```

---

## Part 7 — Show the evidence

- **In the window:** the *Blocked by Microsoft Entra Internet Access policy* message and its **Connection ID**.
- **In GSA:** look for the blocked call in the Global Secure Access traffic logs, as described in the [GSA MCP firewall guide](../gsa-mcp-firewall-demo/README.md), and in Sentinel if you connected it there. Search with the time of the call or the Connection ID from the message.
- **In Defender:** the prompt-injection alert from the [Claude Code + Defender guide](../claude-code-defender-demo/README.md), and Claude Code under **Agents → Local agents**.

---

## Before you present — checklist

- [ ] The VM is running and the GSA client shows **Connected**.
- [ ] `node -e "fetch('https://<APP_NAME>.azurewebsites.net/')..."` prints `status 200` (Part 1).
- [ ] `claude mcp list` (with `CLAUDE_CONFIG_DIR` set) shows the server as **Connected**.
- [ ] `node C:\Demo\tools\agent.mjs` shows three ALLOWED and one BLOCKED.
- [ ] The stub was restarted after your last change, and you opened a **new** Claude Code window.
- [ ] You know which Defender incidents to classify first, as in the Defender guide.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `node agent.mjs` prints `fatal: fetch failed` | Node does not trust the GSA inspection CA, often a PEM that is base64-encoded twice | Part 1 |
| Claude Code or Node prints *Ignoring extra certs … load failed* | `NODE_EXTRA_CA_CERTS` points to an invalid PEM | Part 1 |
| Claude Code only ever replies with the canned text | The stub is the original, or `ENABLE_TOOL_SEARCH=false` is missing, or the server is not registered | Part 2, the launcher, Part 3 |
| A later prompt repeats the first answer | An old stub that answers any tool result | Use the stub in `kit/` and restart it, then open a new window |
| The blocked export is retried in a loop | Same cause | Same fix. Stop the stuck `claude` process by ID first |
| The prompt picks the wrong tool | The first matching keyword wins | Reword the prompt, or reorder the table in `model-stub.js` |
| `claude mcp list` shows the server as **Failed** | The URL is wrong, or you did not use `/mcp`, or GSA is blocking the whole server | Test with the script agent, and check the GSA policy |
| All four calls are **allowed**, including the export | The MCP firewall policy or the forwarding profile does not cover this VM | Check the policy and profile in the GSA guide, and that the GSA client is connected |
| `Method not allowed (stateless server)` in a browser | Expected: a GET to a POST-only endpoint | Use the root URL for a browser check and `/mcp` for MCP traffic |
| Run Command says *Conflict: Run command extension execution is in progress* | A previous Run Command is still running, for example a hung `claude` process | Wait, or use the managed run command API to stop that process |
| `ToolSearch` appears in the stub log instead of MCP tool names | Tool search is on | Set `ENABLE_TOOL_SEARCH=false` in the launcher |

---

## Files in this folder

| File | Purpose |
|---|---|
| [`README.md`](README.md) | This guide |
| [`PROMPTS.md`](PROMPTS.md) | Copy-paste Scout prompts to build and run it |
| [`kit/model-stub.js`](kit/model-stub.js) | Local stub model with the keyword-to-tool-call router |
| [`kit/agent.mjs`](kit/agent.mjs) | Dependency-free script agent that calls the MCP server and labels ALLOWED / BLOCKED |
| [`kit/Start-ClaudeDemo.cmd`](kit/Start-ClaudeDemo.cmd) | Claude Code launcher with `ENABLE_TOOL_SEARCH=false` |
| [`kit/Run-McpAgent.cmd`](kit/Run-McpAgent.cmd) | Double-click launcher for the script agent |

All data returned by the server is synthetic. No keys or tenant values are stored here.
