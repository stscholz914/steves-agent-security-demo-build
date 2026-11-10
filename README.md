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

### Which one do I want?

- **Controlling what agents do over the network** (which tools an agent may call, inspected inline): start with the GSA MCP firewall demo.
- **Detecting and blocking malicious prompts on the endpoint itself:** start with the Claude Code + Defender demo.
- **Giving an open-source agent (LangGraph) a real Entra identity with no secrets, running outside Azure, and showing it in Agent 365:** start with the LangGraph on Amazon EKS demo.

The first two are complementary. One enforces at the network edge, the other on the device. The third is about **identity and observability** for an agent that runs on someone else's infrastructure.

---

## What each demo contains

- A **step-by-step build guide** (`README.md`) with prerequisites and a troubleshooting table.
- The **source files** needed to build it, such as server code, client config and launchers.
- **Copy-paste prompts** to have an AI agent build the demo for you.

The GSA MCP firewall guide opens with a section on the design constraints that decide the architecture. The Claude Code + Defender guide also includes a Word copy, a `kit/` folder of ready-to-copy files, and a reference section with the values from my own build so you can compare. The LangGraph on EKS guide adds a `PROMPTS.md` of Scout prompts, ready-made PowerShell scripts to build, pause, delete and verify the AWS side, and a section on keeping the AWS bill near zero.

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

Each demo gets its own folder named `<topic>-demo/` containing a `README.md` as a complete guide, plus its source files. New demos are added to the table above.

---

## Licence

MIT. See [`LICENSE`](LICENSE). Use, copy and adapt freely. There is no warranty and no official support.

*Last updated 10 November 2026.*
