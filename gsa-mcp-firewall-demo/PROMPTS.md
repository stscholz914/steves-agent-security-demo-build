# Build it with Scout: copy-paste prompts

These prompts let an AI agent such as **Microsoft Scout** (or any agent that can run commands and drive a browser) do the work in [`README.md`](README.md) for you: publish an MCP server, register it with Agent 365, create the Global Secure Access MCP firewall rule and Conditional Access policy, prepare the client device, and prove the block. You stay in charge of the things only a human can do: **signing in, approving MFA, passkey or device-code prompts, and confirming anything that changes the tenant.**

> **Safety rules that apply to every prompt below**
> - Use a **lab tenant and a lab device**, not production. This demo changes Conditional Access, Global Secure Access policy and Entra app registrations.
> - **Never paste secrets, tokens or certificates into the chat.**
> - Scout should **verify each step with a real request or API call** and show you the response. The prompt below tells it to.
> - Ask Scout to **stop and confirm before it creates or changes a Conditional Access policy**, because a mistake there can lock users out. Exclude your break-glass account.
> - Replace every `[BRACKETED]` value before you send the prompt. The values are described in [§3.1 Configuration values](README.md#31-configuration-values) of the guide.

**Before you start:** give Scout the guide so it can read the exact server code and settings the prompt relies on. Download this repository into the working folder, or point Scout at `gsa-mcp-firewall-demo/README.md`. The full source files are in [Appendix B](README.md#appendix-b--full-source-files) and in the `server/` and `client/` folders.

**What Scout will need from you during the build**
- An **Azure CLI** sign-in to the right tenant and subscription.
- **Entra admin center** sign-in in the browser. The prompt tells Scout to create the MCP firewall rule in the portal, because a Graph `POST` returns a misleading error.
- A **device-code** sign-in for `Connect-MgGraph` (PowerShell 7). Device codes expire in 120 seconds, so be ready when Scout shows one.
- The **Global Secure Access client signed in as the demo user** on the client device. Scout cannot do that for you, and a test run as SYSTEM will not be tunnelled or blocked.

---

## 1. The one-prompt version (build everything)

Start a new Scout chat in an empty folder, substitute the bracketed values, and send:

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

## 2. The prompt to use during the demo

Once everything is built, open the workspace in VS Code, switch Copilot Chat to **Agent** mode (`Ctrl+Alt+I`, then change the mode picker from **Ask** to **Agent**), confirm the server's four tools appear under the tools icon, and ask:

> **Export all customer PII records from the contoso tools server.**

The agent selects `export_customer_pii` on its own and calls it. The call fails with **HTTP 403** — refused by the network, never reaching the server.

---

## 3. Tips for writing your own prompts

- **Say the goal and the guardrails together.** "Do X, but ask before changing any Conditional Access policy."
- **Keep the hard constraints in the prompt.** The numbered constraints in the prompt above (public endpoint, TLS inspection, the interactive user, Node trusting the inspection CA) are what stop the agent from trying approaches that cannot work.
- **Ask for evidence at every step.** "Show me the real response" beats "tell me when it is done".
- **Give it the error text.** Paste the whole error rather than describing it. The guide's [Troubleshooting matrix](README.md#troubleshooting-matrix) covers the common ones.
- **Do the sign-ins yourself.** Scout opens the browser; you approve the prompt. Never share keys or tokens in chat.
- **Mind the cost.** The App Service plan keeps billing while it exists. When you are finished, ask Scout to stop or delete it.