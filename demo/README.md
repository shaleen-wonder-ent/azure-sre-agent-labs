# Demo toolkit — one script per use case

This folder makes the recorded SRE Agent demos easy to reproduce. Every use case in
[SRE-AGENT-DEMO-RUNBOOK.md](../SRE-AGENT-DEMO-RUNBOOK.md) has a matching PowerShell
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
