# Azure SRE Agent — Deploy, Break, Watch It Fix

Deploy an **Azure SRE Agent** next to a real Azure workload, trigger a realistic incident with one
command, and watch the agent investigate, explain the root cause, and remediate — with approval gates.

You do **not** need to be an SRE expert. Follow the three steps below.

```
  ┌─────────────┐      ┌──────────────────┐     ┌────────────────────────────┐
  │ 1. DEPLOY   │ ──>  │ 2. WARM UP       │ ──> │ 3. WATCH / FIX             │
  │ labs + agent│      │ trigger incident │     │ agent investigates & fixes │
  └─────────────┘      └──────────────────┘     └────────────────────────────┘
   Deploy-Sre...ps1     demo/Warmup-UC*.ps1      https://sre.azure.com
```

- **Deploy** with one script — `Deploy-SreAgentLabs.ps1` picks the labs, prompts for what it needs, and provisions everything.
- **Warm up** each demo with one script — `demo/Warmup-UC##.ps1` injects the fault and prints the exact prompt to paste.
- **Watch** the agent work in the portal, then approve the fix.

---

## Prerequisites

### Tools

| Tool | Install (Windows) | Install (macOS) |
|------|-------------------|-----------------|
| [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) | `winget install Microsoft.PowerShell` | `brew install powershell/tap/powershell` |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.60+ | `winget install Microsoft.AzureCLI` | `brew install azure-cli` |
| [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) 1.9+ | `winget install Microsoft.Azd` | `brew install azd` |
| [Git](https://git-scm.com/) 2.x (includes Git Bash) | `winget install Git.Git` | `brew install git` |
| [Python](https://python.org) 3.10+ | `winget install Python.Python.3.12` | `brew install python3` |
| [GitHub CLI](https://cli.github.com/) *(only for GitHub demos)* | `winget install GitHub.cli` | `brew install gh` |

> **Windows note:** after installing Python, turn OFF the Store aliases at
> **Settings → Apps → Advanced app settings → App execution aliases** for `python.exe` / `python3.exe`.

### Azure

- An active Azure subscription with the **Owner** role (needed to create role assignments).
- Sign in and select your subscription:
  ```powershell
  az login
  az account set --subscription "<your-subscription-id>"
  ```

---

## Step 1 — Deploy the labs and the agent

Run the launcher from the repo root. It shows the 14 use cases, lets you pick, warns about cost, asks
for anything it needs (passwords are generated for you; GitHub details are prompted only when required),
and provisions after you confirm.

```powershell
# See what would happen — makes NO Azure changes
pwsh ./Deploy-SreAgentLabs.ps1 -PlanOnly

# Interactive: pick use cases, confirm, deploy
pwsh ./Deploy-SreAgentLabs.ps1

# Or deploy specific use cases directly (comma-separated)
pwsh ./Deploy-SreAgentLabs.ps1 -Scenarios '1,6,12'
```

**New to this?** Start with **use case 1** only — it's the smallest, cheapest lab:

```powershell
pwsh ./Deploy-SreAgentLabs.ps1 -Scenarios '1'
```

Each lab creates its own SRE Agent. When the script finishes it prints the agent portal link, or open
**<https://sre.azure.com>** and select your agent.

> **GitHub-connected demos** (the app-fix and compliance demos) ask for a `owner/repo` and an optional
> GitHub token. The token is used only for that run and is never stored. To skip GitHub, add `-SkipGitHub`.

---

## Step 2 — One-time agent setup

Some use cases use pre-loaded skills and datasets. Run this **once** before your first demo:

```powershell
pwsh ./demo/Invoke-OneTimeSetup.ps1
# add -IncludeGrubifyGitHub to also wire the GitHub app-fix demo (needs `gh auth login`)
```

---

## Step 3 — Warm up a use case and watch the agent fix it

Right before you want to show a demo, run its warm-up script. It checks prerequisites, triggers the
incident, waits if needed, and **prints the exact prompt to paste** into the agent (start a new thread).

```powershell
# Example: application outage
pwsh ./demo/Warmup-UC01-AppOutage.ps1
```

Then:

1. Open **<https://sre.azure.com>** and select the lab's agent.
2. Start a **new chat thread** and paste the printed prompt (event-driven demos like UC14 need no prompt — the agent picks up the alert automatically).
3. Watch the agent build a timeline, rank causes, and name the root cause.
4. Where a fix is offered, **you approve** — the agent won't make impactful changes on its own.

Every warm-up script accepts `-PromptOnly` (just print the prompt) and `-SkipPrereqCheck`.
See [demo/README.md](demo/README.md) for all options and the reset/cleanup commands.

---

## The 14 use cases

| # | Use case | Lab (agent) | Warm-up script |
|---|----------|-------------|----------------|
| 1 | Application outage root cause analysis | zava-learning | [`demo/Warmup-UC01-AppOutage.ps1`](demo/Warmup-UC01-AppOutage.ps1) |
| 2 | Connectivity diagnostics (hub ↔ spoke ↔ internet) | zava-learning | [`demo/Warmup-UC02-Connectivity.ps1`](demo/Warmup-UC02-Connectivity.ps1) |
| 3 | VM & infrastructure incident investigation | vm-cosmosdb | [`demo/Warmup-UC03-VmIncident.ps1`](demo/Warmup-UC03-VmIncident.ps1) |
| 4 | Azure SQL Managed Instance performance | enterprise-operations | [`demo/Warmup-UC04-SqlMiPerformance.ps1`](demo/Warmup-UC04-SqlMiPerformance.ps1) |
| 5 | VM availability report (past 30 days) | vm-cosmosdb | [`demo/Warmup-UC05-VmAvailability.ps1`](demo/Warmup-UC05-VmAvailability.ps1) |
| 6 | Resources added / removed (past 7 days) | enterprise-operations | [`demo/Warmup-UC06-ResourceLifecycle.ps1`](demo/Warmup-UC06-ResourceLifecycle.ps1) |
| 7 | Everything changed in the last 24 hours | enterprise-operations | [`demo/Warmup-UC07-ChangeDigest.ps1`](demo/Warmup-UC07-ChangeDigest.ps1) |
| 8 | Entra authentication troubleshooting | enterprise-operations | [`demo/Warmup-UC08-EntraAuth.ps1`](demo/Warmup-UC08-EntraAuth.ps1) |
| 9 | Capacity exhaustion prediction | enterprise-operations | [`demo/Warmup-UC09-CapacityForecast.ps1`](demo/Warmup-UC09-CapacityForecast.ps1) |
| 10 | Failed deployment investigation | enterprise-operations | [`demo/Warmup-UC10-FailedDeployment.ps1`](demo/Warmup-UC10-FailedDeployment.ps1) |
| 11 | Azure cost anomaly detection | enterprise-operations | [`demo/Warmup-UC11-CostAnomaly.ps1`](demo/Warmup-UC11-CostAnomaly.ps1) |
| 12 | Security incident investigation | enterprise-operations | [`demo/Warmup-UC12-SecurityIncident.ps1`](demo/Warmup-UC12-SecurityIncident.ps1) |
| 13 | Multi-subscription operational health | enterprise-operations | [`demo/Warmup-UC13-FleetHealth.ps1`](demo/Warmup-UC13-FleetHealth.ps1) |
| 14 | App OOM → agent-authored fix PR → deploy | starter-lab | [`demo/Warmup-UC14-OomToPr.ps1`](demo/Warmup-UC14-OomToPr.ps1) |

Full prompts, expected highlights, and reset steps: [demo runbook](archive/reference/SRE-AGENT-DEMO-RUNBOOK.md).

---

## Clean up

```powershell
# Reset a live incident after recording (examples)
pwsh ./demo/Warmup-UC04-SqlMiPerformance.ps1 -Reset
pwsh ./demo/Warmup-UC12-SecurityIncident.ps1 -Cleanup

# Tear down a lab's Azure resources (run from the lab folder)
cd labs/starter-lab
azd down --force --purge
```

Each lab is independent, so you only pay for what you deploy. Tear down labs you're done with.

---

## Cost posture (why this is efficient)

Every use case starts with **Azure-native, no-extra-cost** signals — platform metrics, Activity Log,
Resource Health, Resource Graph, and service APIs — and only adds Log Analytics ingestion selectively.

- 🟢 **Native / default** — no additional telemetry cost (metrics, Activity Log, Resource Health, Resource Graph).
- 🟡 **Optional / license-dependent** — chargeable only when enabled (alerts, Defender findings, Conditional Access).
- 🔴 **Log Analytics ingestion** — charged by data ingested/retained (App Insights traces, guest logs, flow logs).

Full per-use-case breakdown with citations: [Telemetry Cost & Consumption Evidence](archive/reference/AZURE-SRE-AGENT-COST-CONSUMPTION.md).

---

## Regions, data residency & pricing

**Before you deploy in a customer tenant, know two things:**

**1. Where your data is processed.** The agent runs in **one region** you pick, and that region is
where its compute/processing lives. With RBAC it can manage resources in **any** region or
subscription you grant — so the agent's region is *not* its reach. If Azure SRE Agent isn't available
in your country yet and you deploy it elsewhere, the agent's processing happens in **that other
region**. Key transparency facts:

- The agent does **not** copy your raw logs/metrics into a separate store — it keeps *synthesized*
  summaries, conversation threads, and memory (all in **per-agent**, isolated storage; nothing shared
  between customers).
- It's **RBAC-scoped to the resource groups you choose**, uses **secretless, short-lived credentials**,
  and in **Review mode nothing that writes runs without your approval**.
- Telemetry goes to **your own** Application Insights.

**2. What it costs.** Billing is in **Azure Agent Units (AAU)** = a fixed **always-on** charge
(**4 AAU/agent-hour**, until the agent is deleted) **plus** a variable **active-flow** charge metered
from LLM tokens (input/output/cache) — billed on **tokens consumed while actively working, not on how
long a query runs** (waiting for your approval is free). The full doc has a worked example (e.g. an
"under-utilized VMs" report ≈ 35 AAU on Claude Opus 4.6, ≈$3.5 at the listed rate).

➡️ Full detail — supported regions list, what is/isn't stored, the token→AAU formula, model rates, and
cost controls: **[Regions, Data Residency & Pricing](archive/reference/AZURE-SRE-AGENT-DATA-RESIDENCY-AND-PRICING.md)**.

---

## Repository layout

| Path | What it is |
|------|-----------|
| [Deploy-SreAgentLabs.ps1](Deploy-SreAgentLabs.ps1) | One launcher to pick and deploy the labs. |
| [demo/](demo/) | One warm-up script per use case + the one-time setup ([demo/README.md](demo/README.md)). |
| [labs/](labs/) | The deployable labs (each has its own `azd` project and README). |
| [deployment/scenarios.json](deployment/scenarios.json) | Use-case → lab manifest used by the launcher. |
| [archive/reference/](archive/reference/) | Deep-dive docs: use-case catalog, cost evidence, regions/data-residency/pricing, product guide, demo runbook. |
| [archive/](archive/) | Parked content: third-party labs, the `sreagent-templates` toolkit, and [resources & links](archive/resources.md). |

---

## Learn more

- **Product overview & scope model:** [Demo Guide](archive/reference/AZURE-SRE-AGENT-DEMO-GUIDE-2026-08-06.md)
- **Use-case catalog (data sources, run modes):** [Use Cases](archive/reference/AZURE-SRE-AGENT-USE-CASES.md)
- **Regions, data residency & pricing:** [Data Residency & Pricing](archive/reference/AZURE-SRE-AGENT-DATA-RESIDENCY-AND-PRICING.md)
- **Videos, blogs, and community links:** [archive/resources.md](archive/resources.md)
- **Report issues:** <https://github.com/microsoft/sre-agent/issues>
- **Security policy:** [SECURITY.md](SECURITY.md) · **License:** [LICENSE](LICENSE)
