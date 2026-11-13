# Steve's Agent Security Demo Build

This is my repo of **hands-on demo builds for securing AI agents** on the Microsoft security stack. Each demo is a complete, repeatable build guide with the source files and prompts needed to recreate it, so you can stand it up in your own lab and run it yourself.

**It will keep growing.** I add a new folder each time I build a demo I think is worth sharing, so expect more over time.

---

## What's in here

| Demo | What it shows | Main products | Start here |
|---|---|---|---|
| **GSA MCP firewall** | An AI agent in VS Code calls an MCP tool that bulk-exports customer PII. Global Secure Access blocks that one tool call with HTTP 403 while allowing three lower-risk tools on the same server. Evidence in the GSA traffic logs and Microsoft Sentinel. | Entra Global Secure Access (Internet Access, TLS inspection, MCP firewall), Conditional Access, Agent 365 registration, Azure App Service, Sentinel, VS Code with GitHub Copilot | [`gsa-mcp-firewall-demo/`](gsa-mcp-firewall-demo/README.md) |
| **Claude Code + Defender AI agent runtime protection** | Claude Code on a Windows VM is blocked by Defender for Endpoint when it receives a prompt-injection test string. A local stub model means no Claude subscription or API key is needed. Evidence in the Defender alert, including the prompt text. | Defender for Endpoint AI agent runtime protection (Preview), Claude Code, Defender advanced hunting, Microsoft 365 admin center Agents | [`claude-code-defender-demo/`](claude-code-defender-demo/README.md) |
| **LangGraph agent on Amazon EKS with the Agent 365 SDK** | An open-source LangGraph agent runs on Kubernetes in AWS with a Microsoft Entra agent identity and **no stored secret**: Entra trusts the cluster's own token. It calls Azure OpenAI and Microsoft Graph as itself, is refused a permission it was not given, and emits Agent 365 telemetry. Written for people who are not AWS or Linux experts, with a **delete and rebuild** routine that takes the AWS cost to about $0 between demos, and Scout prompts to build it for you. | Microsoft Entra Agent ID (agent blueprint, agent identity, federated credential), Microsoft Agent 365 SDK and registry, Azure OpenAI, Microsoft Graph, Amazon EKS, LangGraph | [`langgraph-agent365-kubernetes-demo/`](langgraph-agent365-kubernetes-demo/README.md) |
| **Purview DLP for Microsoft 365 Copilot** | Copilot refuses to use files labelled Customer PII, M&A or HR, refuses prompts containing an SSN or credit card number, and skips web search when a prompt contains a passport or licence number. A Finance-labelled file is still summarised (the control), and an unlabelled transcript with pasted PII shows the gap. Evidence in Purview Activity explorer. | Microsoft Purview DLP (Microsoft 365 Copilot location), sensitivity labels, Microsoft 365 Copilot, SharePoint | [`purview-copilot-dlp-demo/`](purview-copilot-dlp-demo/README.md) |
| **Local Claude Code agent + MCP firewall** | Joins the two builds above. A local stub model is extended so Claude Code on the demo VM calls the MCP server through Global Secure Access: list accounts, balance and health are allowed, the PII export is blocked with a Connection ID. A dependency-free script agent runs the same calls and labels each ALLOWED or BLOCKED. Defender still blocks the prompt-injection string on the same agent. | Claude Code, Entra Global Secure Access (Internet Access, TLS inspection, MCP firewall), Defender for Endpoint AI agent runtime protection (Preview), MCP, Node.js | [`claude-codelocal-agent/`](claude-codelocal-agent/README.md) |

### Which one do I want?

- **Controlling what agents do over the network** (which tools an agent may call, inspected inline): start with the GSA MCP firewall demo.
- **Detecting and blocking malicious prompts on the endpoint itself:** start with the Claude Code + Defender demo.
- **Giving an open-source agent (LangGraph) a real Entra identity with no secrets, running outside Azure, and showing it in Agent 365:** start with the LangGraph on Amazon EKS demo.
- **Stopping Copilot from using or leaking sensitive data (labelled files, SSNs and card numbers in prompts, web search):** start with the Purview DLP for Microsoft 365 Copilot demo.
- **Seeing both controls act on one agent (network block on its MCP tool call, endpoint block on its prompt):** start with the Local Claude Code agent + MCP firewall demo, after building the two it joins.

The first two are complementary. One enforces at the network edge, the other on the device. The local Claude Code agent demo puts both on the same agent. The LangGraph demo is about **identity and observability** for an agent that runs on someone else's infrastructure.

---

## Build them with Scout (the easy way)

Every demo has a **`PROMPTS.md`** next to its guide: copy-paste prompts you can give to **Microsoft Scout** (or any AI agent that can run commands and use a browser) so it builds the demo for you while you approve the sign-ins. Pick a demo, open its prompts, and paste.

| Demo | Prompts |
|---|---|
| GSA MCP firewall | [`gsa-mcp-firewall-demo/PROMPTS.md`](gsa-mcp-firewall-demo/PROMPTS.md): a context block, the full build prompt (with the hard constraints already in it), thirteen stage prompts from publishing the server to tearing it down, troubleshooting prompts, and the prompt to use during the demo |
| Claude Code + Defender AI agent runtime protection | [`claude-code-defender-demo/PROMPTS.md`](claude-code-defender-demo/PROMPTS.md): a context block, a one-shot prompt and ten stage prompts |
| LangGraph agent on Amazon EKS with the Agent 365 SDK | [`langgraph-agent365-kubernetes-demo/PROMPTS.md`](langgraph-agent365-kubernetes-demo/PROMPTS.md): a one-prompt build, step prompts, cost-saving delete and rebuild prompts, and troubleshooting prompts |
| Purview DLP for Microsoft 365 Copilot | [`purview-copilot-dlp-demo/PROMPTS.md`](purview-copilot-dlp-demo/PROMPTS.md): a context block, a one-prompt build, eleven stage prompts from labels to tear-down, troubleshooting prompts and a prompt for the live demo |
| Local Claude Code agent + MCP firewall | [`claude-codelocal-agent/PROMPTS.md`](claude-codelocal-agent/PROMPTS.md): a context block, a one-prompt build, nine stage prompts from the CA check to tear-down, troubleshooting prompts and a prompt for the live demo |

**How to use them**

1. Get this repository onto the machine Scout runs on (clone it, or download the ZIP) so Scout can read the guide and the source files the prompts refer to.
2. Open the `PROMPTS.md` for your demo. Replace every placeholder (`<ANGLE_BRACKETS>` or `[BRACKETS]`) with your own values.
3. Paste the context block or one-shot prompt into a new Scout chat. Use the step prompts to go one stage at a time, or to repeat a single stage later.
4. Stay in the loop for **sign-ins, MFA and passkey approvals**, and for anything that changes your tenant or costs money. The prompts tell Scout to stop and ask.

**Ground rules:** use a lab tenant, never paste secrets into the chat, and ask Scout to show real command output as evidence. The prompts are the same ones embedded in each guide's README (or its appendix), collected in one place so they are easy to find.

---
## What each demo contains

- A **step-by-step build guide** (`README.md`) with prerequisites and a troubleshooting table.
- The **source files** needed to build it, such as server code, client config and launchers.
- **Copy-paste prompts** to have an AI agent build the demo for you, collected in a `PROMPTS.md` in each demo folder (see [Build them with Scout](#build-them-with-scout-the-easy-way)).

The GSA MCP firewall guide opens with a section on the design constraints that decide the architecture. The Claude Code + Defender guide also includes a Word copy, a `kit/` folder of ready-to-copy files, and a reference section with the values from my own build so you can compare. The Purview DLP guide adds ready-made PowerShell scripts for the labels and the policy, a Python generator for synthetic sample data with label stamping, and a nine-prompt test script with expected results. The local Claude Code agent guide adds a tool-calling stub model, a script agent and a launcher in `kit/`, and a check for the GSA inspection CA file that Node needs. The LangGraph on EKS guide adds a `PROMPTS.md` of Scout prompts, ready-made PowerShell scripts to build, pause, delete and verify the AWS side, and a section on keeping the AWS bill near zero.

---

## How to use these guides

1. Open the demo's `README.md` and read the **prerequisites** and any **constraints** notes first. They save the most time.
2. Replace every `<PLACEHOLDER>` with your own values. Placeholders are written in angle brackets, for example `<APP_NAME>`.
3. Follow the parts in order and use the verification steps to check each one worked before moving on.
4. Do the setup at least a day before you need to present. Some of these services take hours to propagate.

---

## Good to know

- **These are demos, not production guidance.** They are built to show a control working clearly, not to be a hardened reference design.
- **Several features are in Preview.** Behaviour, names and requirements can change. The Claude Code + Defender guide says when it was last verified and links the Microsoft Learn pages it relies on. Check the product documentation if something behaves differently from the guide.
- **Only use them where you are authorised to test.** Several demos deliberately use strings or traffic that look like attacks.
- **All data is synthetic.** Account numbers, SSNs and emails in the samples are fake. No real customer data is used or needed.
- **No secrets are stored here.** Keys in the samples are placeholders, and tenant names and IDs have been removed.
- **Cost.** Some demos create billable Azure or AWS resources, such as App Service plans, VMs and an EKS cluster (about $0.26 an hour while it exists). Deallocate or delete them when you finish. The LangGraph on EKS demo includes scripts that delete the AWS side and verify the cost is back to about $0.

---

## Adding new demos

Each demo gets its own folder named `<topic>-demo/` containing a `README.md` as a complete guide, a `PROMPTS.md` of Scout prompts that build it, and its source files. New demos are added to the table above and to the Scout prompts table.

---

## Licence

MIT. See [`LICENSE`](LICENSE). Use, copy and adapt freely. There is no warranty and no official support.

*Last updated 13 November 2026.*
