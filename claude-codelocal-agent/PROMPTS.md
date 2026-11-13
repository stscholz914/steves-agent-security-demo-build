# Build it with Scout: copy-paste prompts

These prompts let an AI agent such as **Microsoft Scout** (or any agent that can run commands and drive a browser) do the work in [`README.md`](README.md) for you: upgrading the local stub model so Claude Code can call the demo MCP server, registering the server, running the script agent, and proving that Global Secure Access allows three tools and blocks the PII export. You stay in charge of the things only a human can do: **signing in, approving MFA, passkey or device-code prompts, and confirming anything that changes the VM, the tenant or GSA.**

This demo builds on two others in this repo, so do those first: [`gsa-mcp-firewall-demo/`](../gsa-mcp-firewall-demo/PROMPTS.md) (the MCP server and the GSA policy) and [`claude-code-defender-demo/`](../claude-code-defender-demo/PROMPTS.md) (the VM, Claude Code and the stub).

> **Safety rules that apply to every prompt below**
> - Use a **lab tenant and a lab VM**, not production. The PII tool returns synthetic data and is blocked, but the traffic looks like data exfiltration on purpose, so only run this where you are authorised to test.
> - **Never paste secrets into the chat.** That includes the Defender onboarding package and any token or key.
> - Scout should **verify every step with real command output** and **ask before anything destructive**. The prompts below tell it to.
> - Replace every `<PLACEHOLDER>` before you send a prompt. The values are listed in [Placeholders](README.md#3-placeholders) in the guide.

**Before you start:** give Scout the guide so it can read the exact code referenced by the prompts. Download this repository into the working folder, or point Scout at `claude-codelocal-agent/README.md`. The stage prompts refer to "Part 1" to "Part 7" of that guide and to the files in `claude-codelocal-agent/kit/`.

---

## 1. What Scout needs from you

- Azure CLI signed in to the right tenant and subscription, or tell Scout to run `az login --tenant <TENANT_ID>`.
- The two earlier demos already built: the MCP server is running and the GSA policy exists, and the VM has Claude Code and the stub.
- You, for any sign-in or passkey prompt. Scout cannot approve those.

---

## 2. Paste this first: the context block

```text
Context for this whole session. Do not act on anything outside it.

- Tenant: <TENANT_ID>. Before any change, run `az account show` and STOP if the tenant does not match.
- Subscription: <SUBSCRIPTION_ID>. Resource group: <RESOURCE_GROUP>. VM: <VM_NAME> (Windows 11, Global Secure Access client installed, Claude Code and the local stub model already built).
- MCP server: https://<APP_NAME>.azurewebsites.net/mcp (tools: get_server_health, list_accounts, get_account_balance, export_customer_pii). It only accepts POST, so a browser GET to /mcp showing "Method not allowed (stateless server)" is normal.
- Goal: a local Claude Code agent and a script agent on the VM that call the MCP server through Global Secure Access. Three tools must be ALLOWED and export_customer_pii must be BLOCKED by the Entra Internet Access MCP firewall policy. No Claude subscription or API key is used: the stub model answers.
- The guide is claude-codelocal-agent/README.md and the files are in claude-codelocal-agent/kit/. Use that code exactly; do not rewrite it.
- Rules:
  1. Verify every step with a real command or portal check and report the actual output. Do not claim success without evidence.
  2. Never print or save secrets or tokens.
  3. Warn me before any action that changes the VM, the tenant, or GSA settings, and wait for my OK on anything destructive.
  4. Azure Run Command on this VM can raise a Defender alert. Batch VM work into few scripts and tell me at the end which incident to classify.
  5. Never start a command that can hang (such as an interactive claude session) inside Run Command. Use `claude -p` with a timeout, and stop any stuck process by its process ID.
  6. If a step fails, find the cause before retrying. Do not guess.
```

---

## 3. The one-prompt version (build everything)

Paste the context block above, then this:

```text
Build the local Claude Code agent + MCP firewall demo on <VM_NAME> in <RESOURCE_GROUP>, following claude-codelocal-agent/README.md step by step.

Do the stages in order: (1) check state, (2) make sure Node trusts the GSA TLS inspection CA, (3) copy the kit files to the VM and restart the stub, (4) register the MCP server with Claude Code, (5) run the script agent and show ALLOWED/BLOCKED, (6) test Claude Code non-interactively with prompts that trigger each tool, including several prompts in one session, (7) summarise the evidence.

Rules: stop and ask me before any sign-in you cannot complete, before changing anything outside <VM_NAME>, and before touching any Defender incident. Verify each stage with real command output and show it to me. Batch VM work into as few Run Command scripts as you can, never leave an interactive claude process running in Run Command, and list the Defender incidents I should classify at the end. Never print secrets. At the end, give me a pass/fail table for each stage and the exact steps to run the demo live.
```

---

## 4. Step-by-step prompts

Use these one at a time if you prefer to stay in control, or to repeat a single stage later. Paste the context block first in a new session.

**1. Check the starting state (Part 2 prerequisites)**

```text
Start <VM_NAME> if it is deallocated. Then, using one Run Command script, report: whether the GSA client services are running, the machine value of NODE_EXTRA_CA_CERTS, whether C:\Demo\tools\model-stub.js exists and its size, `claude --version`, `node --version`, and the output of `claude mcp list` with CLAUDE_CONFIG_DIR set to C:\Demo\claude-config. Do not change anything.
```

**2. Make Node trust the GSA inspection CA (Part 1)**

```text
On <VM_NAME>, test whether Node can reach https://<APP_NAME>.azurewebsites.net/ with a fetch. If it fails with SELF_SIGNED_CERT_IN_CHAIN or the NODE_EXTRA_CA_CERTS file will not load, inspect the PEM file. If it is base64-encoded twice (the body starts with LS0tLS1CRUdJTi), back it up, decode it once as in Part 1 of the guide, and retest. Show me the certificate subject and issuer and the fetch result. Do not change any other certificate or trust setting.
```

**3. Install the kit and restart the stub (Part 2)**

```text
On <VM_NAME>, back up C:\Demo\tools\model-stub.js as model-stub.js.bak, then copy kit/model-stub.js and kit/agent.mjs to C:\Demo\tools, kit/Start-ClaudeDemo.cmd to C:\Demo, and kit/Run-McpAgent.cmd to C:\Demo and the all-users desktop. Set the default URL in agent.mjs to https://<APP_NAME>.azurewebsites.net/mcp. Restart the stub by stopping the node process whose command line contains model-stub.js (by process ID) and starting it again. Prove it is listening on 127.0.0.1:8787 and show the file hashes.
```

**4. Register the MCP server with Claude Code (Part 3)**

```text
On <VM_NAME>, with CLAUDE_CONFIG_DIR set to C:\Demo\claude-config, register the MCP server at user scope: `claude mcp add --transport http --scope user demo-tools https://<APP_NAME>.azurewebsites.net/mcp`. Then run `claude mcp list` and show me that it is Connected. Confirm that C:\Demo\Start-ClaudeDemo.cmd sets ENABLE_TOOL_SEARCH=false.
```

**5. Run the script agent (Part 5)**

```text
On <VM_NAME>, run `node C:\Demo\tools\agent.mjs` and show me the whole output. Confirm get_server_health, list_accounts and get_account_balance are ALLOWED and export_customer_pii is BLOCKED, and quote the Connection ID in the block message. If all four are allowed, do not change any policy: tell me, and check that the GSA client is connected and the VM is in the forwarding profile scope.
```

**6. Test Claude Code with several prompts (Parts 4 and 6)**

```text
Test Claude Code on <VM_NAME> non-interactively. Use `claude -p` with the Foundry environment variables from Start-ClaudeDemo.cmd, `--allowedTools mcp__demo-tools`, a 30 second timeout per call, and `--continue` after the first call so all prompts share one session. Send, in order: "Benign health check", "Lists customer accounts", "Bulk exports customer PII", "Show the balance for ACC-1003", "Benign health check", "Bulk exports customer PII". Show me each reply. Each prompt must return its own result, the two export prompts must be refused with the GSA message, and nothing may loop. If a call hangs, stop that claude process by its process ID and tell me.
```

**7. Show the evidence (Part 7)**

```text
Open the Global Secure Access traffic logs in the Entra admin center and find the blocked export_customer_pii call from <VM_NAME> from the last hour, using the time or the Connection ID from the block message. Show me the row (action, destination, policy). Then show me the prompt-injection alert from the Defender demo in the Defender portal. Tell me honestly if a log row has not appeared yet; GSA logs can lag.
```

**8. Get ready to present**

```text
List the open Defender incidents for <VM_NAME>. Tell me which contain test alerts or the "Azure RunScript" alert. Propose which to classify or resolve so that a live run opens a fresh incident, and wait for my OK before changing any incident. Then give me the checklist from "Before you present" in the guide with each item marked pass or fail from a real check.
```

**9. Tear down**

```text
Deallocate <VM_NAME> to stop billing. Do not delete the VM or its disks. If the MCP server's App Service plan is only for this demo, tell me its tier and monthly cost and ask whether to stop or delete it. Confirm the power state of the VM.
```

---

## 5. Troubleshooting prompts

**The script agent says "fetch failed"**

```text
`node C:\Demo\tools\agent.mjs` on <VM_NAME> prints "fetch failed". Find the cause, not just a workaround: print the error cause code, the issuer of the certificate Node receives from https://<APP_NAME>.azurewebsites.net, and the NODE_EXTRA_CA_CERTS path and first lines of the file. Fix the CA file as in Part 1 of the guide and retest. Do not disable certificate verification.
```

**Claude Code only gives the canned reply**

```text
Claude Code on <VM_NAME> always answers with the canned stub text and never calls an MCP tool. Check, in this order: the stub file is the one from kit/ (hash), the stub restarted after the change, ENABLE_TOOL_SEARCH=false is set in the launcher, `claude mcp list` shows the server as Connected, and the stub log shows the MCP tool names in the request (not ToolSearch). Report which check failed and fix only that.
```

**Later prompts repeat the first answer**

```text
In one Claude Code session on <VM_NAME>, every prompt after the first returns the first tool result, or the blocked export loops. Compare C:\Demo\tools\model-stub.js with kit/model-stub.js. If they differ, install the kit version and restart the stub. Then repeat the six-prompt test from step 6 in a new session and show me the results.
```

**All four calls are allowed**

```text
The script agent shows export_customer_pii as ALLOWED on <VM_NAME>. Check, read-only: the GSA client is connected, the Internet Access forwarding profile is on, the VM user is in the policy scope, TLS inspection is on, and the MCP firewall policy exists and is linked to the profile. Show me what each check returned. Do not change any policy without asking me.
```

**Run Command says "Conflict"**

```text
Azure Run Command on <VM_NAME> says another execution is in progress. Find the process that is holding it using the managed run command API (not the classic one), show me the process list, and ask me before stopping anything. Stop only the stuck process, by its process ID, and delete any temporary managed run commands you created.
```

---

## 6. Prompt to use during the live demo

```text
I am presenting. On <VM_NAME>, run the script agent and show me the ALLOWED/BLOCKED lines, then give me one sentence for each of the four tools that explains why it was allowed or blocked. Do not change any setting, and do not run anything else.
```

---

## 7. Tips for writing your own prompts

- **Say the goal and the guardrails together.** "Do X, but ask before anything that changes the VM or a Defender incident."
- **Name the guide and the Part.** Scout works best when it can read the README and reuse the exact code from `kit/` rather than inventing it.
- **Ask for evidence.** "Show me the command output" beats "tell me when it is done".
- **Give it the error text.** Paste the whole error rather than describing it.
- **Do the sign-ins yourself.** Scout opens the browser; you approve the prompt.
- **Never run an interactive program inside Run Command.** It can hang the extension for a long time. Use `claude -p` with a timeout.
