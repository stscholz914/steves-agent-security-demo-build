# Build it with Scout: copy-paste prompts

These prompts let an AI agent such as **Microsoft Scout** (or any agent that can run commands and drive a browser) do the work in [`README.md`](README.md) for you. You stay in charge of the things only a human can do: **signing in, approving passkey/MFA prompts, and confirming anything that changes your tenant.**

> **Safety rules that apply to every prompt below**
> - Use a **lab tenant**, never production. These prompts create labels, a DLP policy and a SharePoint site.
> - **Never paste passwords or tokens into the chat.** Sign in through the browser (or a device code) when Scout asks.
> - Scout should **ask before it changes anything in the tenant**, and show you the real command output as evidence.
> - Replace every `<PLACEHOLDER>` before you send a prompt.

---

## 1. Context block (paste this first)

```text
I am building a Microsoft Purview demo: DLP policies that stop Microsoft 365 Copilot from using sensitive data.
Guide and scripts: https://github.com/stscholz914/steves-agent-security-demo-build
(folder purview-copilot-dlp-demo). Download the repo into the current folder and read that folder's README.md.

Facts:
- Lab tenant domain: <TENANT_DOMAIN>. Tenant ID: <TENANT_ID>.
- Sign in as <ADMIN_UPN> for everything. I will approve sign-ins. If the browser picks the wrong account, use a device code.
- Demo users (they have Copilot licences): <USER1_UPN> and <USER2_UPN>.
- I am not a PowerShell or Purview expert. Explain what you are doing in plain English as you go.

Rules:
- Work one stage at a time and wait for me to say "next".
- Ask me before you change anything in the tenant.
- Show real command output as evidence. Never print tokens.
- If something fails, read the Troubleshooting table in the README, apply the fix, and tell me what you did.
Reply "ready" and wait.
```

---

## 2. The one-prompt version (build everything)

```text
Follow purview-copilot-dlp-demo\README.md from Part 1 to Part 5, in order, using my context block.
1. Create scripts\config.ps1 from the example and fill in my tenant, users and object IDs.
2. Connect to Purview PowerShell (scripts\00-connect.ps1) and run scripts\10-create-labels.ps1.
3. Generate the sample data, stamp the labels with the real label GUIDs from my tenant, create a SharePoint team site
   with both demo users as members, and upload the files to the folders listed in Part 3.
4. Run scripts\40-create-dlp-policy.ps1, then create rule 3 (block web search) in the Purview portal.
5. STOP and ask me before running scripts\50-enable-policy.ps1.
6. After the policy is enabled, print the policy mode and the three rules as evidence.
Do not run the Part 6 prompts for me. Tell me when it is ready and how long to wait for propagation.
```

---

## 3. Stage-by-stage prompts

Use these one at a time to stay in control, or to repeat a single stage later. Each one names the README part it follows.

### Stage 1: Get the repo and set my values (Part 1)

```text
Clone the repo if you have not already. Copy scripts\config.example.ps1 to config.ps1 and fill it in with my tenant
<TENANT_DOMAIN>, tenant ID <TENANT_ID> and demo users <USER1_UPN> and <USER2_UPN>. Look up each user's Entra object ID
and put those in. Show me the file with nothing secret in it and confirm config.ps1 is git-ignored.
```

### Stage 2: Connect to Purview (Part 2)

```text
Run scripts\00-connect.ps1 against <TENANT_DOMAIN>. If the browser picks the wrong account, use Connect-IPPSSession -Device
and give me the code and link, then wait. When connected, show me the existing DLP policies and confirm the tenant is the lab.
```

### Stage 3: Create and publish the labels (Part 2)

```text
Run scripts\10-create-labels.ps1. Then run the verify command from Part 2 and show me the four AID- labels with their GUIDs.
If a parent label is missing, tell me what you will create and ask first.
```

### Stage 4: Generate the sample data (Part 3.1)

```text
In data\, install python-docx and openpyxl, run gen.py to create the seven synthetic files in an out folder, and list them
with sizes. Confirm that all names, SSNs and card numbers are synthetic.
```

### Stage 5: Stamp the labels (Part 3.2)

```text
Look up the GUIDs for Customer PII, Mergers and Acquisitions (MNPI), HR, Finance, General and Public in my tenant. Run stamp.py
for each file as shown in Part 3.2 using my tenant ID, leaving the support transcript unlabelled. List the stamped folder.
```

### Stage 6: SharePoint site and upload (Part 3.3)

```text
Create a SharePoint team site called "AI Demo Data" with <USER1_UPN> and <USER2_UPN> as members. In its Documents library
create the folders Customers, Corporate-Development, Finance, HR, General and Support, and upload each stamped file to the
folder listed in Part 3.1. Then show me the library with the Sensitivity column so I can see each label. Ask me before creating the site.
```

### Stage 7: Create the DLP policy, rules 1 and 2 (Part 4.1)

```text
Run scripts\40-create-dlp-policy.ps1. Show me the policy mode (it should be TestWithoutNotifications), its location and the two
rules. Explain in plain English what each rule blocks.
```

### Stage 8: Rule 3 in the portal (Part 4.2)

```text
Open the Microsoft Purview portal, edit the policy "AI Demo - Copilot DLP" and add rule 3 exactly as in Part 4.2: SITs
U.S. / U.K. Passport Number and U.S. Driver's License Number, action Prevent Copilot from processing content > Performing
web searches. Pause if I need to approve a sign-in. Save, then run the Part 4 verify command and show me three rules.
```

### Stage 9: Turn it on (Part 5)

```text
Ask me to confirm. If I say yes, run scripts\50-enable-policy.ps1 and show me the policy mode and rule status. Tell me
how long to wait before testing and what DistributionStatus means.
```

### Stage 10: Check Copilot (Part 6)

```text
I will run the Part 6 prompts in Copilot myself. For each result I paste back, tell me whether it matches the Expected
result column and, if not, which Troubleshooting row applies.
```

### Stage 11: Tear it down (Remove the demo)

```text
Run scripts\90-remove-demo.ps1 as a dry run and show me what it would remove. After I confirm, re-run it with -Confirm,
then tell me how to delete the SharePoint site and empty its recycle bin.
```

---

## 4. Troubleshooting prompts

### Copilot still reads a file it should not

```text
Copilot summarised <FILE_NAME> even though it should be blocked. Check, in this order: (1) the policy mode and
DistributionStatus, (2) that rule 1 is not disabled and lists the right label GUIDs, (3) that the file really carries the label
in SharePoint, (4) that <USER_UPN> is in the policy scope. Show the evidence for each and tell me the most likely cause.
```

### A prompt with an SSN was not blocked

```text
This prompt was not blocked: <PROMPT>. Check rule 2's sensitive information types and confidence, confirm the policy mode is
Enable, and tell me whether the number in my prompt is one the classifier would recognise. Suggest a prompt from gen.py that will work.
```

### Labels are missing or not showing

```text
The Sensitivity column is empty for <FILE_NAME>. Check whether labels for Office files in SharePoint are turned on, re-run
stamp.py for that file with the right GUID, re-upload it, and tell me how long to wait.
```

### Explain it to me

```text
Explain how the three rules differ and why labels and sensitive information types need separate rules. Use an analogy a
security manager would follow, and list the three limits I should mention in the demo (uploaded files, opened Office files, propagation time).
```

---

## 5. The prompt to use during the demo

```text
I am running the Copilot DLP demo for <AUDIENCE>. Walk me through the nine prompts in Part 6 one at a time. After each result I
paste, give me a one-sentence explanation I can say out loud, and where to show the evidence in Purview Activity explorer.
Finish with a five-line summary, including the labelling gap in prompt 9.
```

---

## Tips for writing your own prompts

- **Say the goal and the guardrails together.** "Do X, but ask before anything that changes the tenant."
- **Name the folder, script and README part.** Scout works best reading the guide and running the scripts, not inventing commands.
- **Paste the whole error** rather than describing it.
- **Do the sign-ins yourself.** Scout opens the browser; you approve. Never share passwords in chat.
