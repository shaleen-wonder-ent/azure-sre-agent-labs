# Demo toolkit — one script per use case

This folder makes the recorded SRE Agent demos easy to reproduce. Every use case in
[the demo runbook](../archive/reference/SRE-AGENT-DEMO-RUNBOOK.md) has a matching PowerShell
**warm-up script** that checks prerequisites, injects the fault or seeds the incident,
and prints the exact prompt to paste into the agent.

## What's here

| Script | Purpose |
|---|---|
| `Invoke-OneTimeSetup.ps1` | Run **once** before recording — configures the enterprise-operations agent and installs the UC8/9/11/13 dataset skills (optionally wires the Grubify GitHub deployment for UC14). |
| `Warmup-UC01-AppOutage.ps1` | UC1 — Application outage RCA (Zava Learning). |
| `Warmup-UC02-Connectivity.ps1` | UC2 — Connectivity hub↔spoke↔internet (Zava Learning). |
| `Warmup-UC03-VmIncident.ps1` | UC3 — VM & infrastructure incident (vm-cosmosdb). |
| `Warmup-UC04-SqlMiPerformance.ps1` | UC4 — SQL MI performance (seeds a live blocking transaction; prints the session IDs). |
| `Warmup-UC05-VmAvailability.ps1` | UC5 — VM availability report, 30 days (vm-cosmosdb). |
| `Warmup-UC06-ResourceLifecycle.ps1` | UC6 — Resources added/removed, 7 days. |
| `Warmup-UC07-ChangeDigest.ps1` | UC7 — Everything changed, 24 hours. |
| `Warmup-UC08-EntraAuth.ps1` | UC8 — Entra authentication troubleshooting (dataset). |
| `Warmup-UC09-CapacityForecast.ps1` | UC9 — Capacity exhaustion prediction (dataset). |
| `Warmup-UC10-FailedDeployment.ps1` | UC10 — Failed deployment investigation. |
| `Warmup-UC11-CostAnomaly.ps1` | UC11 — Cost anomaly detection (dataset). |
| `Warmup-UC12-SecurityIncident.ps1` | UC12 — Security incident investigation (opens RDP; restore with `-Cleanup`). |
| `Warmup-UC13-FleetHealth.ps1` | UC13 — Multi-subscription health (dataset + multi-sub RBAC). |
| `Warmup-UC14-OomToPr.ps1` | UC14 — App OOM → fix PR → deploy (event-driven, no chat prompt). |
| `DemoCommon.psm1` | Shared helpers (prereq checks, Git Bash discovery, prompt output). |

## Prerequisites

- PowerShell 7+
- Azure CLI (`az`) signed in: `az login`
- Azure Developer CLI (`azd`)
- Git for Windows (Git Bash) — the vm-cosmosdb and starter-lab warm-ups call bash scripts
- The relevant lab must already be **deployed** (see [Deploy-SreAgentLabs.ps1](../Deploy-SreAgentLabs.ps1))
- For UC14 GitHub flow: GitHub CLI (`gh`) authenticated (`gh auth login`)

Each warm-up script verifies its own tools and Azure sign-in before doing anything.

## Typical flow

```powershell
# 1. Deploy the labs you want to demo (interactive picker + GitHub prompts)
./Deploy-SreAgentLabs.ps1

# 2. One-time agent configuration + dataset skills (run once)
./demo/Invoke-OneTimeSetup.ps1                 # add -IncludeGrubifyGitHub for UC14

# 3. Warm up a specific demo right before you record it
./demo/Warmup-UC06-ResourceLifecycle.ps1       # seeds, waits ~2 min, prints the prompt
```

Paste the printed prompt into the SRE Agent in a **new thread**, then record the highlight.

## Sample deployment output

The following transcript shows a successful `starter-lab` deployment. Values entered by
the operator are called out between output blocks. Subscription details, tenant IDs,
generated resource names, endpoints, and credentials are sanitized.

<details>
<summary>Expand sanitized deployment transcript</summary>

```text
PS C:\path\to\azure-sre-agent-labs> pwsh ./Deploy-SreAgentLabs.ps1

== Available scenarios ==
 1. Application outage root cause analysis [deployable]
 2. Connectivity diagnostics: hub to spoke to internet [deployable]
 3. VM and infrastructure incident investigation [deployable]
 4. Azure SQL Managed Instance performance analysis [guided setup]
 5. VM availability report (past 30 days) [deployable]
 6. Services or resources added or removed (past week) [deployable]
 7. Show everything changed in last 24 hours [deployable]
 8. Entra authentication troubleshooting [guided setup]
 9. Capacity exhaustion prediction [deployable]
10. Failed deployment investigation [deployable]
11. Azure cost anomaly detection [deployable]
12. Security incident investigation [deployable]
13. Multi-subscription operational health overview [guided setup]
Enter 'all' or comma-separated scenario numbers (for example 2,4,7,10):
```

> **Operator input:** `1`

```text
== Selected use cases ==
 1. Application outage root cause analysis -> starter-lab (deployable)

== Unique lab packages ==
DEPLOY  starter-lab
				Deploys Container Apps, Container Registry, Log Analytics, Application Insights, and an SRE Agent.

== GitHub integration ==
These labs use GitHub: starter-lab
starter-lab wires GitHub Actions deployment (gh CLI + OIDC); deployment-compliance connects a code repo (OAuth).
GitHub repository as owner/repo (e.g., shaleen-wonder-ent/grubify) (press Enter to skip and configure later):
```

> **Operator input:** `shaleen-wonder-ent/grubify`

```text
Optional: paste a GitHub PAT to authenticate the gh CLI non-interactively (used only for this run, never stored).
GitHub PAT (press Enter to use browser/gh login instead):
```

> **Operator input:** Press Enter. No PAT was entered or captured.

```text
== Azure target ==
Subscription: [REDACTED-SUBSCRIPTION-NAME] ([REDACTED-SUBSCRIPTION-ID])
Tenant:       [REDACTED-TENANT-ID]
Type DEPLOY to provision the listed resources:
```

> **Operator input:** `DEPLOY`

```text
GitHub repository for this run: shaleen-wonder-ent/grubify

== Deploying starter-lab ==

Packaging services (azd package)

Provisioning Azure resources (azd provision)
Provisioning Azure resources can take some time.

Subscription: [REDACTED-SUBSCRIPTION-NAME] ([REDACTED-SUBSCRIPTION-ID])
Location: East US 2

	(✓) Done: Resource group: rg-srelab-starter
	(✓) Done: Log Analytics workspace: law-[RESOURCE-SUFFIX]
	(✓) Done: Application Insights: appi-[RESOURCE-SUFFIX]
	(✓) Done: Container Registry: acrcagrubify[RESOURCE-SUFFIX]
	(✓) Done: Container Apps Environment: cae-[RESOURCE-SUFFIX]
	(✓) Done: Container App: ca-grubify-[RESOURCE-SUFFIX]
	(✓) Done: Container App: ca-grubify-fe-[RESOURCE-SUFFIX]
	(✓) Done: SRE Agent: sre-agent-[RESOURCE-SUFFIX]

Deploying services (azd deploy)

SUCCESS: Your up workflow to provision and deploy to Azure completed.

=============================================
	SRE Agent Lab - Post-Provision Setup
=============================================

Agent: https://[REDACTED-SRE-AGENT-ENDPOINT]
Resource group: rg-srelab-starter

Step 0/5: Building Grubify container images in ACR...
	 Built: acrcagrubify[RESOURCE-SUFFIX].azurecr.io/grubify-api:latest
	 API deployed: https://[REDACTED-API-ENDPOINT]
	 Frontend built
	 Frontend deployed: https://[REDACTED-FRONTEND-ENDPOINT]
	 CORS configured

Step 1/5: Uploading knowledge base...
	 Uploaded: github-issue-triage.md grubify-architecture.md http-500-errors.md incident-report-template.md

Step 2/5: Creating/updating incident-handler subagent...
	 Using full config with GitHub tools
	 Skill: grubify-pr-delivery
	 Created: incident-handler
	 Created: public-exposure-auditor

Step 3/5: Enabling Azure Monitor incident platform...
	 Azure Monitor enabled + DevOps & Python tools enabled
	 Response plan -> incident-handler
	 Scheduled task: audit-public-exposure (daily at 06:00 UTC -> public-exposure-auditor)

Step 4/5: GitHub integration...
	 Approval hook: grubify-write-approval
	 GitHub OAuth connector created
	 Created: code-analyzer
	 Created: issue-triager
	 Scheduled task: triage-grubify-issues (every 12h -> issue-triager)
	 Code repo: shaleen-wonder-ent/grubify
	 Created 5 sample customer issues in shaleen-wonder-ent/grubify

=============================================
	Verifying what was provisioned...
=============================================

	Knowledge Base: 4 files indexed
	Subagents: incident-handler, public-exposure-auditor, code-analyzer, issue-triager
	Connectors: app-insights, log-analytics, azure-monitor, github
	Response Plans: grubify-http-errors -> incident-handler
	Incident Platform: Azure Monitor
	Scheduled Tasks: triage-grubify-issues, audit-public-exposure

=============================================
	SRE Agent Lab Setup Complete!
=============================================

	Agent Portal:  https://sre.azure.com
	Agent API:     https://[REDACTED-SRE-AGENT-ENDPOINT]
	Grubify API:   https://[REDACTED-API-ENDPOINT]
	Grubify UI:    https://[REDACTED-FRONTEND-ENDPOINT]
	Resource Group: rg-srelab-starter

== Deployment summary ==
All automated lab deployments completed. Review any guided enterprise steps above.
```

</details>

## Common parameters

Most warm-up scripts accept:

| Parameter | Meaning |
|---|---|
| `-SubscriptionId` | Target subscription (defaults to the current `az` context). |
| `-PromptOnly` | Skip the fault/seed and just print the prompt. |
| `-SkipPrereqCheck` | Skip the tool/sign-in checks (for repeated runs). |
| `-EnvironmentPrefix` | Used by UC1/UC2 to derive `rg-zava-learning-<prefix>-zava` (default `srelab`). |

Seed-based scenarios (UC6/7/10/12) also accept `-NoWait`, `-WaitSeconds`, and `-Cleanup`.
Dataset scenarios (UC8/9/11/13) accept `-EnsureSkill` to (re)install their skill.

## Reset after recording

```powershell
./demo/Warmup-UC04-SqlMiPerformance.ps1 -Reset      # clear the SQL MI blocking fault
./demo/Warmup-UC12-SecurityIncident.ps1 -Cleanup    # restore the secure NSG baseline
./demo/Warmup-UC06-ResourceLifecycle.ps1 -Cleanup   # delete the shared seed RG (UC6/7/10)
# UC1/UC2: pwsh ./chaos/fix-app.ps1 / fix-nsg.ps1 from labs/zava-learning
# UC3: CPU stress self-clears after 10 minutes
# UC14: the merged fix on main is the reset
```

See the runbook for the full per-use-case detail and expected highlights.
