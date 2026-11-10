# Build it with Scout: copy-paste prompts

These prompts let an AI agent such as **Microsoft Scout** (or any agent that can run commands and drive a browser) do the work in [`README.md`](README.md) for you: onboarding a Windows VM to Defender for Endpoint, enabling AI agent runtime protection, installing Claude Code with a local stub model, and proving the block. You stay in charge of the things only a human can do: **signing in, approving MFA, passkey or device-code prompts, and confirming anything that changes the VM, the tenant or Defender.**

> **Safety rules that apply to every prompt below**
> - Use a **lab tenant and a lab VM**, not production. The test prompt is harmless but deliberately looks like an attack, so only run this where you are authorised to test.
> - **Never paste secrets into the chat.** Treat the Defender onboarding package as a secret.
> - Scout should **verify every step with real command output** and **ask before anything destructive**. The prompts below tell it to.
> - Replace every `<PLACEHOLDER>` before you send a prompt. The values are listed in [Placeholders](README.md#3-placeholders) in the guide.

**Before you start:** give Scout the guide so it can read the exact code and settings referenced by the prompts. Download this repository into the working folder, or point Scout at `claude-code-defender-demo/README.md`. The stage prompts refer to "Part 5", "Part 6" and "Part 8" of that guide.

---

## 1. What Scout needs from you

- Azure CLI signed in to the right tenant and subscription, or tell Scout to run `az login --tenant <TENANT_ID>`.
- A Defender portal admin sign-in in the browser. Scout cannot approve MFA, passkeys or device codes for you.
- You, for the onboarding package download if your portal session needs approval.

---

## 2. Paste this first: the context block

```text
Context for this whole session. Do not act on anything outside it.

- Tenant: <TENANT_ID>. Before any change, run `az account show` and STOP if the tenant does not match.
- Subscription: <SUBSCRIPTION_ID>. Resource group: <RESOURCE_GROUP>. VM: <VM_NAME> (Windows 11, no public IP).
- Goal: a demo where Claude Code on the VM is blocked by Microsoft Defender AI agent runtime protection, using a local stub model so no Claude subscription is needed.
- Rules:
  1. Verify every step with a real command or portal check and report the actual output. Do not claim success without evidence.
  2. Never print or save secrets, tokens or the onboarding package contents. Do not commit them anywhere.
  3. Warn me before any action that changes the VM, the tenant, or Defender settings, and wait for my OK on anything destructive.
  4. Azure Run Command on this VM can raise a Defender alert ("Azure RunScript used to deploy malicious code"). Keep Run Command calls to a minimum, batch work into few scripts, and tell me at the end which incident to classify.
  5. If a step fails, find the cause before retrying. Do not guess.
```

---

## 3. The one-prompt version (build everything)

Paste the context block above, then this:

```text
Build the Claude Code + Microsoft Defender AI agent runtime protection demo on <VM_NAME> in <RESOURCE_GROUP>, tenant <TENANT_ID>, following the setup guide "Claude Code + Defender AI Agent Runtime Protection — Demo Build Guide" step by step.

Do the stages in order: (1) check state, (2) onboard to Defender for Endpoint, (3) enable AI agent runtime protection on the Beta channel in Block mode, (4) install Node and Claude Code, (5) create and start the local stub model as a boot task, (6) create the launcher, test prompt and shortcut, (7) test end to end with a benign prompt and the test injection prompt, (8) confirm the Defender alert and show the detected prompt.

Rules: stop and ask me before any sign-in you cannot complete, before changing anything outside <VM_NAME>, and before touching any Defender incident. Verify each stage with real command output or portal evidence and show it to me. Batch VM work into as few Run Command scripts as you can, because Run Command raises a Defender alert; list the incidents I should classify at the end. Never print secrets or the onboarding package. At the end, give me a pass/fail table for each stage and the exact commands I need to run the demo live.
```

---

## 4. Step-by-step prompts

Use these one at a time if you prefer to stay in control, or to repeat a single stage later. Paste the context block first in a new session.

**1. Check the starting state**

```text
Start <VM_NAME> if it is deallocated. Then, using one Run Command script, report: Windows version, Defender AMRunningMode, RealTimeProtectionEnabled, AntivirusSignatureVersion, whether the Sense service exists, and whether node and claude are installed. Do not change anything.
```

**2. Onboard to Defender for Endpoint**

```text
Onboard <VM_NAME> to Microsoft Defender for Endpoint with the local script method. Open the Defender portal in the browser (Settings > Endpoints > Onboarding, Windows 10 and 11, Local Script), download the package, run it on the VM, and verify Sense is Running and OnboardingState is 1. Treat the package as a secret: delete it from the VM and my machine afterwards. Tell me when the device shows in Assets > Devices.
```

**3. Configure Defender**

```text
On <VM_NAME>, set Defender platform and engine update channels to Beta, update signatures, and set AiAgentProtection to Block. Verify and show me: PlatformUpdatesChannel and EngineUpdatesChannel both 2, AiAgentProtection 1, signature version at least 1.451.224.0, and the contents of HKLM:\SOFTWARE\Policies\ClaudeCode "Settings". If the channels or signatures have not applied yet, wait and recheck rather than continuing.
```

**4. Install Node and Claude Code**

```text
On <VM_NAME>, install Node.js v24.21.0 (machine-wide MSI), then install Claude Code with `npm install -g @anthropic-ai/claude-code`. Make sure `claude` is on the machine PATH for all users. Show me `claude --version` and where it resolves.
```

**5. Build the stub model**

```text
On <VM_NAME>, create C:\Demo\tools\model-stub.js using the exact code in section Part 5 of the setup guide. Register a scheduled task named DemoModelStub (SYSTEM, highest, At startup) that runs it with node, start it, and prove it works with a POST to http://127.0.0.1:8787/anthropic/v1/messages that returns the canned reply.
```

**6. Launcher, shortcut and test prompt**

```text
On <VM_NAME>, create C:\Demo\Start-ClaudeDemo.cmd and C:\Demo\test-prompt.txt exactly as in Part 6 of the setup guide, using a placeholder API key. Create the all-users desktop shortcut "Claude Code - Defender demo" and grant Users modify rights on C:\Demo. Confirm every file exists.
```

**7. Test end to end**

```text
Test the Claude Code demo on <VM_NAME> end to end. Run Claude Code through the launcher settings in a pseudo-terminal, since you cannot see the interactive window. First send "hello" and confirm the stub reply (not blocked). Then send the exact prompt from C:\Demo\test-prompt.txt and confirm the "blocked by Microsoft Defender" message. Then check the Defender portal and report the alert name, severity and the incident it joined. Do not claim a toast or window you did not observe.
```

**8. Show the prompt**

```text
In the Defender portal, open the newest "Suspicious AI prompt injection blocked" alert for <VM_NAME>, expand What happened > Read more, and show me the Prompt line. Then run the SecurityAlert advanced hunting query from Part 8 of the setup guide and show the result. If Sentinel is not connected, say so and use the AlertInfo query instead.
```

**9. Get ready to present**

```text
List the open Defender incidents for <VM_NAME>. Tell me which contain test alerts or the "Azure RunScript" alert. Propose which to classify or resolve so that a live run opens a fresh incident, and wait for my OK before changing any incident.
```

**10. Tear down**

```text
Deallocate <VM_NAME> to stop billing. Do not delete the VM or its disks. Confirm the power state.
```

---

## 5. Tips for writing your own prompts

- **Say the goal and the guardrails together.** "Do X, but ask before anything that changes the VM or a Defender incident."
- **Name the guide and the Part.** Scout works best when it can read the README and reuse the exact code (for example "Part 5 of the setup guide") rather than inventing it.
- **Ask for evidence.** "Show me the command output" beats "tell me when it is done".
- **Give it the error text.** Paste the whole error rather than describing it.
- **Do the sign-ins yourself.** Scout opens the browser; you approve the prompt. Never share keys, tokens or the onboarding package in chat.
- **Mind Run Command.** On the reference build, Azure Run Command activity raised a Defender alert. Keep Run Command calls few and near the build, not right before a live demo.