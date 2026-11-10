# Build it with Scout: copy-paste prompts

These prompts let an AI agent such as **Microsoft Scout** (or any agent that can run commands and drive a browser) do the work in [`README.md`](README.md) for you. You stay in charge of the three things only a human can do: **signing in, approving passkey/MFA prompts, and confirming anything that costs money or deletes something.**

> **Safety rules that apply to every prompt below**
> - **Never paste AWS access keys, client secrets or passwords into the chat.** Sign in through the browser when Scout asks.
> - Use a **lab tenant and a demo AWS account**, not production.
> - Scout should **ask before it creates anything billable or deletes anything**. The prompts below tell it to.
> - Replace every `<PLACEHOLDER>` before you send a prompt.

---

## 1. The one-prompt version (build everything)

Start a new Scout chat in an empty folder and send:

```text
I want to build the demo in this guide: a LangGraph agent running on Amazon EKS with a Microsoft
Entra agent identity (no stored secrets) and the Microsoft Agent 365 SDK.

Guide and scripts: https://github.com/stscholz914/steves-agent-security-demo-build
(folder langgraph-agent365-kubernetes-demo). Download it into the current folder first.

Context:
- I am NOT an AWS or Linux person. Explain what you are doing in plain English as you go.
- My Entra tenant ID is <TENANT_ID> (a lab tenant). My Azure subscription is <SUBSCRIPTION_NAME>.
- My AWS account is for demos only. Use region <AWS_REGION>.
- Use a unique Azure OpenAI account name starting with <PREFIX>.

Follow README.md step by step, in order:
1. Install the tools with scripts\setup-device.ps1 (tell me if it needs administrator rights).
2. Create scripts\config.ps1 from the example and fill it in as we collect values.
3. Sign in to Azure and AWS. Tell me when you need me to approve a browser prompt, then wait.
4. Run scripts\10-create-azure-openai.ps1.
5. In the Entra admin center, create the agent blueprint "LangGraph Blueprint" and the agent identity
   "LangGraph Agent (Amazon EKS)" using the portal wizards. Do NOT add any secret or certificate.
   Record the IDs in config.ps1.
6. Run scripts\20-grant-agent-access.ps1, then scripts\30-register-agent.ps1.
7. STOP and show me the estimated AWS cost (about $0.26/hour) and ask me to confirm before running
   scripts\60-rebuild-eks.ps1.
8. After it finishes, run the demo helpers (Test-DemoReady, Show-NoSecrets, Show-Identity, Ask-Agent,
   Show-Spans) and summarise what each proved, quoting the key lines.

Rules:
- Ask me before anything that costs money or deletes anything.
- Never print secrets or tokens. The identity output shows claims only, which is fine.
- If a step fails, read the Troubleshooting table in the README, try the fix, and tell me what you did.
- At the end, remind me how to delete the AWS side and offer to do it.
```

---

## 2. Step-by-step prompts

Use these one at a time if you prefer to stay in control, or to repeat a single step later.

### Install and prepare

```text
Read langgraph-agent365-kubernetes-demo\README.md. Check whether az, aws, kubectl and eksctl are installed
and give me the versions. If anything is missing, tell me what you will install and run
scripts\setup-device.ps1 (it needs an administrator PowerShell, so tell me what to do if you are not elevated).
```

### Sign in

```text
Sign me in to Azure for tenant <TENANT_ID> and to AWS for region <AWS_REGION>. Open the browser for each,
tell me exactly what I need to approve, and wait. Then show me which Azure subscription and which AWS
account number I am connected to, and ask me to confirm they are the demo ones before continuing.
```

### Azure OpenAI

```text
Run scripts\10-create-azure-openai.ps1 with the account name <UNIQUE_NAME>. When it finishes, copy the four
DEMO_OPENAI values into scripts\config.ps1 and confirm that API keys are turned off on the account.
```

### Blueprint and agent identity in the portal

```text
Open the Microsoft Entra admin center for tenant <TENANT_ID> in the browser. Create an agent blueprint named
"LangGraph Blueprint" (Entra ID > Agents > Agent blueprints > New agent blueprint) and an agent identity named
"LangGraph Agent (Amazon EKS)" from it (Agent identities > New agent identity). Pause if I need to approve a
passkey. Do not add any client secret or certificate. Record the blueprint application ID, blueprint object ID
and agent identity object ID in scripts\config.ps1 and show me the three values.
```

### Permissions and registration

```text
Run scripts\20-grant-agent-access.ps1 and then scripts\30-register-agent.ps1. For the device-code sign-in,
tell me the code and link and wait for me. Then confirm in the Microsoft 365 admin center under
Agents > Registry that the agent appears.
```

### Build the AWS side

```text
Tell me the estimated cost, then ask me to confirm. If I say yes, run scripts\60-rebuild-eks.ps1 and keep me
updated at each stage (it takes 25 to 40 minutes). If it stops, work out why from the output and the
Troubleshooting table, fix it, and re-run (it is safe to re-run). When it finishes, show me the identity JSON
and explain in plain English what the pod token and the Entra token prove.
```

### Run and explain the demo

```text
Load scripts\demo-helpers.ps1 and run Test-DemoReady, Show-NoSecrets, Show-Identity, Ask-Agent and Show-Spans.
After each one, explain in one or two sentences, for a non-technical audience, what it proves. Finish with a
five-line summary I can read out to the audience.
```

### Prove there are no secrets in the Entra blueprint

```text
In the Entra admin center, open my LangGraph Blueprint and show me its credentials. Confirm there are zero
client secrets and zero certificates and that there is a federated credential named eks-langgraph-sa.
Take a screenshot.
```

---

## 3. Keep the cost down (delete and set up again)

### Delete the AWS side

```text
I am finished with the demo. Run scripts\62-delete-eks.ps1 to delete the whole AWS side. Before you do, show
me the cluster name, the region and what will be removed, and ask me to confirm. After it finishes, run
scripts\62-delete-eks.ps1 -VerifyOnly and tell me whether AWS cost is about $0. If anything billable is left,
tell me exactly what it is and how to remove it.
```

### Check I am not paying for anything

```text
Run scripts\62-delete-eks.ps1 -VerifyOnly for region <AWS_REGION> and tell me in plain English whether
anything billable is still running, and the rough monthly cost of whatever is left.
```

### Set it up again before a demo

```text
I have a demo on <DATE> at <TIME>. Work out when to start so everything is ready 30 minutes before. At that
time sign me in to AWS again (ask me to approve), run scripts\60-rebuild-eks.ps1, then run Test-DemoReady and
tell me whether I am good to go.
```

### Pause instead of deleting

```text
Pause the demo cluster to save money with scripts\61-scale-eks.ps1 -Nodes 0 and tell me what it still costs
per month. Later, when I say "resume", run it with -Nodes 1 and confirm the agent pod is Running.
```

### Remind me so I never forget

```text
Create a Scout automation that runs every weekday at 6 pm. It should run scripts\62-delete-eks.ps1 -VerifyOnly
for region <AWS_REGION> and, if anything billable exists, message me on Teams with what it is and the
command to remove it. If nothing is left, say nothing.
```

> The automation needs a valid AWS sign-in. AWS sign-ins expire, so if it reports `session expired` it will ask you to run `aws login`.

---

## 4. Customising and troubleshooting

### Add your own tool to the agent

```text
Open agent\app.py. Add a new LangGraph tool called <TOOL_NAME> that <WHAT_IT_DOES>. Keep the Agent 365
SDK setup (configure, CustomLangChainInstrumentor and InvokeAgentScope) unchanged. Tell me which Microsoft
Graph or Azure permission the tool needs, add only that to scripts\20-grant-agent-access.ps1, run it, then
rebuild with scripts\60-rebuild-eks.ps1 and test the new tool with Ask-Agent.
```

### Fix a certificate error

```text
I get this error: <PASTE ERROR>. Look it up in the Troubleshooting table in README.md, explain in plain
English why it happens, and apply the fix. Do not change anything outside this folder without asking me.
```

### AWS says my region or instance type is not allowed

```text
My AWS build failed with: <PASTE ERROR>. Work out whether it is a region restriction, a Free Tier instance
restriction or an account activation problem. Suggest the smallest change (a different DEMO_AWS_REGION or
DEMO_NODE_TYPE in scripts\config.ps1), apply it, and re-run scripts\60-rebuild-eks.ps1.
```

### Explain it to me

```text
Explain how the agent gets its identity with no secret, using the "How the Agent 365 SDK is wired in"
section and agent\identity.py. Use an analogy a security manager would follow, and list the three checks
Entra performs on the Kubernetes token.
```

---

## Tips for writing your own prompts

- **Say the goal and the guardrails together.** "Do X, but ask before anything that costs money or deletes."
- **Name the folder and the script.** Scout works best when it can read the README and run the scripts rather than inventing commands.
- **Ask it to explain as it goes** if you are new to AWS or Linux. It will translate the output for you.
- **Give it the error text.** Paste the whole error rather than describing it.
- **Do the sign-ins yourself.** Scout opens the browser; you approve the prompt. Never share keys or passwords in chat.
