# Build it with Scout: copy-paste prompts

These prompts let an AI agent such as **Microsoft Scout** (or any agent that can run commands and drive a browser) do the work in [`README.md`](README.md) for you: publish an MCP server, register it with Agent 365, create the Global Secure Access MCP firewall rule and Conditional Access policy, prepare the client device, and prove the block. You stay in charge of the things only a human can do: **signing in, approving MFA, passkey or device-code prompts, and confirming anything that changes the tenant.**

> **Safety rules that apply to every prompt below**
> - Use a **lab tenant and a lab device**, not production. This demo changes Conditional Access, Global Secure Access policy and Entra app registrations.
> - **Never paste secrets, tokens or certificates into the chat.**
> - Scout should **verify each step with a real request or API call** and show you the response. The prompt below tells it to.
> - Ask Scout to **stop and confirm before it creates or changes a Conditional Access policy**, because a mistake there can lock users out. Exclude your break-glass account.
> - Replace every placeholder before you send a prompt (`[BRACKETED]` in the one-prompt version, `<ANGLE_BRACKETS>` in the step prompts). The values are described in [§3.1 Configuration values](README.md#31-configuration-values) of the guide.

**Before you start:** give Scout the guide so it can read the exact server code and settings the prompt relies on. Download this repository into the working folder, or point Scout at `gsa-mcp-firewall-demo/README.md`. The full source files are in [Appendix B](README.md#appendix-b--full-source-files) and in the `server/` and `client/` folders.

**What Scout will need from you during the build**
- An **Azure CLI** sign-in to the right tenant and subscription.
- **Entra admin center** sign-in in the browser. The prompt tells Scout to create the MCP firewall rule in the portal, because a Graph `POST` returns a misleading error.
- A **device-code** sign-in for `Connect-MgGraph` (PowerShell 7). Device codes expire in 120 seconds, so be ready when Scout shows one.
- The **Global Secure Access client signed in as the demo user** on the client device. Scout cannot do that for you, and a test run as SYSTEM will not be tunnelled or blocked.

---

## 1. The one-prompt version (build everything)

Start a new Scout chat in an empty folder, substitute the `[BRACKETED]` values, and send. (This is the original prompt from the guide's Appendix A; the step-by-step prompts below use `<ANGLE_BRACKET>` placeholders to match the guide's configuration table.)

````markdown
You are building a demonstration of the Microsoft Entra Global Secure Access (GSA)
MCP firewall. The goal: an AI agent in VS Code calls an MCP tool that bulk-exports
customer PII, and GSA blocks that specific tool call with HTTP 403 while permitting
three lower-risk tools on the same server.

## Environment
- Entra tenant: [TENANT_DOMAIN] (tenant ID [TENANT_ID])
- Azure subscription: [SUBSCRIPTION_ID]
- Resource group: [RESOURCE_GROUP]
- Demo user: [USER_UPN]
- Client device: [DEVICE_NAME], Windows 11, Entra-joined, GSA client installed

## Hard constraints — do not attempt to work around these
1. GSA security profiles are evaluated ONLY on Internet Access and Microsoft
   traffic, never Private Access. The MCP server MUST be published on a public
   HTTPS endpoint. A CA policy carrying a security profile may target only
   "Internet resources with GSA" (5dc48733-b5df-475c-a49b-fa307ef00853) or
   "Microsoft apps with GSA" (c08f52c9-8f03-4558-a0ea-9a4c878cf343).
   Targeting private resources fails with error 1034; "All agent resources"
   fails with error 1142.
2. TLS inspection must be enabled and the client must trust the inspection CA,
   otherwise the firewall cannot read the JSON-RPC payload.
3. The GSA client tunnels traffic for the INTERACTIVE signed-in user. Any test
   run as SYSTEM produces no tunnelling and no block.
4. Node.js does not use the Windows certificate store. Any Node-based MCP client
   requires NODE_EXTRA_CA_CERTS pointing at a PEM of the inspection root CA.

## Tasks
1. Build an MCP server (Node 22, @modelcontextprotocol/sdk, Express, Streamable
   HTTP in stateless mode) exposing four tools with synthetic data:
     - get_server_health    (benign)
     - list_accounts        (low risk)
     - get_account_balance  (sensitive)
     - export_customer_pii  (HIGH RISK — the block target)
   Serve a browser test console at "/" and the MCP endpoint at "/mcp".
2. Publish it to Azure App Service (Linux, Node 22 LTS, Always On, HTTPS-only)
   and verify initialize, tools/list and tools/call all return 200 over public
   HTTPS. If App Service quota is 0 in the chosen region, try another region
   rather than requesting a quota increase.
3. Register the server with Agent 365 using the a365 CLI. The name must begin
   "ext_", be 20 characters or fewer, and the description 80 or fewer. The CLI
   does not roll back on failure and leaves an orphaned Power Platform connector
   that permanently burns the name — choose carefully. Registration creates three
   Entra apps (- BYO, -A365Proxy, -PublicClients). Grant admin consent to
   Tools.ListInvoke.All for both client apps.
4. Create a GSA MCP firewall policy with default action Allow, and a rule:
     name=Block-PII-Export, priority=100, action=block, status=enabled,
     serverUrls=[public /mcp URL] exactMatch,
     toolMatching.names=[export_customer_pii] exactMatch
   Create the rule in the Entra portal — Graph POST returns a misleading
   "missing required property name: Priority" error regardless of payload.
   Once created, manage it via Graph at
   /beta/networkAccess/mcpPolicies/{id}/policyRules
   (NOT /filteringPolicies — that returns 404). The OData type is
   #microsoft.graph.networkaccess.mcpPolicyRule. Azure CLI tokens return 403 on
   networkAccess; use pwsh 7 Connect-MgGraph with
   NetworkAccessPolicy.ReadWrite.All (device codes expire in 120 seconds).
5. Link the MCP policy and a TLS inspection policy into a GSA security profile,
   and attach that profile to a Conditional Access policy targeting
   "Internet resources with GSA" and including the demo user.
6. On the client device: install VS Code and the GitHub Copilot extension
   (not bundled), create a workspace with .vscode/mcp.json pointing at the public
   MCP endpoint and .vscode/settings.json enabling http.systemCertificates.
   Also produce a dependency-free Node fallback client (agent.mjs) using built-in
   fetch, and export the inspection CA to a PEM for NODE_EXTRA_CA_CERTS.
7. Verify end to end: with the GSA client signed in as the demo user, confirm the
   first three tools return 200 and export_customer_pii returns 403. Then confirm
   the traffic log entry shows policyType=mcpFirewall, the rule name, and
   mcpPrimitiveName=export_customer_pii.

## Optional
Create a Sentinel scheduled analytics rule over NetworkAccessTraffic where
PolicyType == "mcpFirewall" and Action == "Block". Note Log Analytics renames
policyRuleName to RuleName and Title-cases Action. alertDetailsOverride allows a
maximum of 3 {{parameters}} in alertDescriptionFormat. In workspaces onboarded to
the unified Defender portal, scheduled rules may produce alerts without incidents
— verify with a SecurityAlert query rather than assuming an incident appears.

## Reporting
After each major step, verify the result with an actual request or API call and
report the real response. Do not assert success without evidence.
````

---

## 2. Step-by-step prompts

Use these one at a time if you prefer to stay in control, or to repeat a single stage later. They use the same `<PLACEHOLDERS>` as [§3.1 Configuration values](README.md#31-configuration-values) in the guide. Paste the context block first in a new session.

### Paste this first: the context block

```text
Context for this whole session. Do not act on anything outside it.

- Tenant: <TENANT_ID>. Before any change, run `az account show` and STOP if the tenant does not match.
- Subscription: <SUBSCRIPTION_ID>. Resource group: <RESOURCE_GROUP>. Region: <LOCATION>.
- App Service: <APP_NAME> (plan <PLAN_NAME>). Agent 365 server name: <MCP_SERVER_NAME>.
- GSA: MCP policy <MCP_POLICY>, security profile <SECURITY_PROFILE>. Demo user: <DEMO_USER_UPN>. Client device: <DEVICE_NAME> (Windows 11, Entra-joined, GSA client installed).
- Goal: an AI agent in VS Code calls an MCP tool that bulk-exports customer PII, and Global Secure Access blocks that one tool call with HTTP 403 while allowing three lower-risk tools on the same server.
- Follow the guide "Global Secure Access MCP Firewall - Demo Build Guide" (gsa-mcp-firewall-demo/README.md) and reuse its code and settings. Use the full source in server/ and client/.
- Hard constraints, do not work around them: (1) the MCP server must be on a public HTTPS endpoint, because security profiles apply only to Internet Access and Microsoft traffic; a Conditional Access policy carrying a profile may target only "Internet resources with GSA"; (2) TLS inspection must be on and the client must trust the inspection CA; (3) GSA tunnels traffic for the interactive signed-in user, so anything run as SYSTEM will not be blocked; (4) Node.js needs NODE_EXTRA_CA_CERTS pointing at a PEM of the inspection root CA.
- Rules:
  1. Verify every step with a real command, request or portal check and report the actual output. Do not claim success without evidence.
  2. Never print or save secrets, tokens or certificates in the chat.
  3. STOP and ask me before creating or changing any Conditional Access policy, and before deleting anything. Exclude my break-glass account from any policy.
  4. If a step fails, find the cause before retrying. Do not guess. Check the guide's Troubleshooting matrix first.
  5. Tell me exactly when I need to sign in or approve a prompt, then wait. Device codes expire in 120 seconds, so tell me the moment you show one.
```

### Stage prompts

**1. Check the starting state (changes nothing)**

```text
Check the prerequisites for the GSA MCP firewall demo and change nothing. Report: the Azure CLI version (need 2.60 or later) and which subscription is active; whether PowerShell 7 and the Microsoft.Graph module are installed; whether this tenant has the Entra Internet Access licence and whether a TLS inspection policy exists in Global Secure Access (Secure > TLS inspection policies); whether <DEMO_USER_UPN> exists and is licensed for GSA; and whether the GSA client on <DEVICE_NAME> is installed and signed in as that user. Give me a pass/fail list and tell me what I need to fix before we continue.
```

**2. Build and publish the MCP server (Part 1)**

```text
Build and publish the MCP server (Part 1 of the guide). Use the files in server/ (package.json, server.js, console.html). Create the Linux App Service plan <PLAN_NAME> (B1) and the web app <APP_NAME> on runtime NODE:22-lts in <RESOURCE_GROUP>, region <LOCATION>. Apply the app settings, startup file "node server.js", Always On and HTTPS-only. Deploy the FULL zip, never a single file. If plan creation fails on quota, try another region instead of requesting quota. The CLI may say "DEPLOYMENT FAILED" even when the site started, so verify with /healthz before troubleshooting. Prove it works with real requests: GET /healthz and a POST to /mcp with initialize and tools/list must both return 200 over public HTTPS, and tools/list must show four tools. Remember /mcp is POST-only (a browser GET returns 405 by design).
```

**3. Register the server with Agent 365 (Part 2)**

```text
Register the server with Agent 365 (Part 2). Before running anything, show me the server name <MCP_SERVER_NAME>, check it starts with "ext_" and is 20 characters or fewer, check the description is 80 or fewer, and ask me to confirm the name. The a365 CLI does not roll back on failure and a failed attempt burns the name permanently, so do not retry blindly. Install the CLI if needed, run `a365 login` (tell me when I must approve), then register with auth type NoAuth, the URL https://<APP_NAME>.azurewebsites.net/mcp and the four tools. Then grant admin consent: Tools.ListInvoke.All on the BYO app for both client apps, and PlatformRuntime.Internal.All on the Agent Tools service principal. Confirm in the Microsoft 365 admin center under Agents > Tools Request (Preview) rather than relying on `a365 develop-mcp list-servers`, which is unreliable. List the three Entra apps it created.
```

**4. Create the MCP firewall policy and block rule (Part 3.1 and 3.2)**

```text
In the Entra admin center, go to Global Secure Access > Secure > MCP firewall and create the policy <MCP_POLICY> with default action Allow. Then create the rule IN THE PORTAL (the Graph POST returns a misleading "missing required property name: Priority" error whatever you send): name Block-PII-Export, priority 100, action Block, status Enabled, server URL https://<APP_NAME>.azurewebsites.net/mcp with Exact match, tool name export_customer_pii with Exact match. Pause if I need to approve a sign-in. Take a screenshot of the saved rule.
```

**5. Verify the rule through Graph (Part 3.3)**

```text
Verify the rule through Microsoft Graph. Azure CLI tokens return 403 on networkAccess, so use PowerShell 7 and Connect-MgGraph with the NetworkAccessPolicy.ReadWrite.All scope and device authentication. Show me the device code and wait; it expires in 120 seconds. Then GET https://graph.microsoft.com/beta/networkAccess/mcpPolicies/{policyId}/policyRules (the collection is mcpPolicies, NOT filteringPolicies, which returns 404) and show me the rule's name, priority, action, status, server URL and tool name. Do not change the rule.
```

**6. Create the security profile (Part 3.5)**

```text
In Global Secure Access, create or edit the security profile <SECURITY_PROFILE> with priority 500 and link two policies: the MCP policy <MCP_POLICY> and a TLS inspection policy. TLS inspection is required because the firewall must read the payload. Do not add anything else. Show me the saved profile and its linked policies.
```

**7. Attach the profile with Conditional Access (Part 4)**

```text
STOP and show me the plan before changing anything. I want a Conditional Access policy that targets ONLY <DEMO_USER_UPN> (exclude my break-glass account), has Target resources set to "Internet resources with GSA" (5dc48733-b5df-475c-a49b-fa307ef00853), and under Session uses the Global Secure Access security profile <SECURITY_PROFILE>. Do not target private resources or "All agent resources"; those fail with errors 1034 and 1142. After I say go, create it. The Entra portal can fail silently on save, so if nothing seems to happen, open the browser dev tools Network tab and read the real error from the Graph call. Confirm the policy exists, is enabled, and show me its settings.
```

**8. Prepare the client device (Part 5)**

```text
On <DEVICE_NAME>, prepare the client (Part 5). Install VS Code and Node LTS silently, and tell me to install the GitHub Copilot extension and sign in with a Copilot-licensed account (it is not bundled). Create C:\mcp-demo-client from client/ with .vscode\mcp.json pointing at https://<APP_NAME>.azurewebsites.net/mcp, .vscode\settings.json with http.systemCertificates and chat.mcp.enabled, and agent.mjs. Export the TLS inspection root CA from LocalMachine\Root to C:\mcp-demo-client\gsa-ca.pem and set NODE_EXTRA_CA_CERTS for the user. Tell me to open a NEW terminal afterwards. Confirm every file exists. Do not sign the GSA client in for me; tell me to do it.
```

**9. Test end to end (Part 6)**

```text
Test the demo end to end. First tell me to confirm the GSA tray icon shows Connected as <DEMO_USER_UPN>. Then, in an INTERACTIVE session (never SYSTEM, which is not tunnelled and will not be blocked), run `node agent.mjs` from C:\mcp-demo-client. Expect get_server_health, list_accounts and get_account_balance to return 200 and export_customer_pii to return 403. Show me the real output. If all four return 200, work through the Troubleshooting matrix: GSA not signed in as the user, user not in the CA policy, test run as SYSTEM, or the server reached over Private Access. Report what you found.
```

**10. Show the evidence (Part 7)**

```text
In Global Secure Access > Monitor > Traffic logs, filter on <APP_NAME>.azurewebsites.net and show me the blocked transaction: action block, responseCode 403, policyType mcpFirewall, policyName <MCP_POLICY>, policyRuleName Block-PII-Export, mcpPrimitiveName export_customer_pii, filteringProfileName <SECURITY_PROFILE>, tlsDetails.action intercepted. Show me the preceding initialize call as an allow on the adjacent row. Then, if Log Analytics is connected, run the NetworkAccessTraffic KQL from Part 7.2. Note Log Analytics renames policyRuleName to RuleName and Title-cases Action (Block/Allow), so KQL written from the Graph schema silently returns zero rows. If the diagnostic settings are not exported, say so rather than guessing.
```

**11. Optional: raise a Sentinel alert (Part 8)**

```text
Create the Sentinel scheduled analytics rule from Part 8: severity High, run every 5 minutes with a 15 minute lookback, one alert per result, entities Account (UserPrincipalName), IP (SourceIp) and URL (DestinationUrl), tactic Exfiltration (T1567), and the display name "GSA blocked MCP tool '{{McpPrimitiveName}}' for {{UserPrincipalName}}". alertDescriptionFormat allows at most 3 {{parameters}}. Trigger the block again, wait for the rule to run, and verify with a SecurityAlert query. In workspaces onboarded to the unified Defender portal, scheduled rules can raise alerts without incidents, so tell me whether an incident actually appeared before I promise one in a demo.
```

**12. The closing beat**

```text
Run the same agent.mjs from a machine that is NOT behind Global Secure Access (or with the GSA client signed out) and show me that all four tools succeed. Then explain in two sentences, for a security audience, why this proves the enforcement is in the network and follows the user's identity, with nothing installed on the server.
```

**13. Tear down and stop the meter**

```text
I am finished with the demo. Show me what is billing: the App Service plan <PLAN_NAME> and anything else in <RESOURCE_GROUP>. Remind me that stopping the web app does NOT stop plan billing; deleting the plan (or scaling it down) does. Ask me which I want, and do not delete the Conditional Access policy, the security profile or the Agent 365 registration without my explicit OK for each one. Confirm the end state.
```

---

## 3. Troubleshooting prompts

```text
All four MCP tools returned 200 and nothing was blocked. Work through the guide's Troubleshooting matrix in order: is the GSA client signed in as <DEMO_USER_UPN>, is that user in the Conditional Access policy, is the server on a public endpoint rather than Private Access, and was the test run interactively rather than as SYSTEM? Check each with real evidence and tell me which one it was.
```

```text
I get this error: <PASTE ERROR>. Look it up in the Troubleshooting matrix in README.md, explain in plain English why it happens, and apply the fix. Do not change anything outside this build without asking me.
```

```text
Explain how the MCP firewall blocked only export_customer_pii and allowed the other three tools on the same server, using Part 3 of the guide. Cover why TLS inspection is required, why the rule matches on both the server URL and the tool name, and why the policy follows the signed-in user rather than the device.
```

---
## 4. The prompt to use during the demo

Once everything is built, open the workspace in VS Code, switch Copilot Chat to **Agent** mode (`Ctrl+Alt+I`, then change the mode picker from **Ask** to **Agent**), confirm the server's four tools appear under the tools icon, and ask:

> **Export all customer PII records from the contoso tools server.**

The agent selects `export_customer_pii` on its own and calls it. The call fails with **HTTP 403** — refused by the network, never reaching the server.

---

## 5. Tips for writing your own prompts

- **Say the goal and the guardrails together.** "Do X, but ask before changing any Conditional Access policy."
- **Keep the hard constraints in the prompt.** The numbered constraints in the prompt above (public endpoint, TLS inspection, the interactive user, Node trusting the inspection CA) are what stop the agent from trying approaches that cannot work.
- **Ask for evidence at every step.** "Show me the real response" beats "tell me when it is done".
- **Give it the error text.** Paste the whole error rather than describing it. The guide's [Troubleshooting matrix](README.md#troubleshooting-matrix) covers the common ones.
- **Do the sign-ins yourself.** Scout opens the browser; you approve the prompt. Never share keys or tokens in chat.
- **Mind the cost.** The App Service plan keeps billing while it exists. When you are finished, ask Scout to stop or delete it.