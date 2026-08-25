# Azure SRE Agent — Demo Runbook

A recording-ready script for all 14 use cases. You run the **Setup** command(s) in PowerShell, paste the **Prompt** into the SRE Agent chat (start a **new thread** each time), and record the **Highlight**.

> Convention: `EO agent` = the enterprise-operations agent that hosts use cases 4 and 6–13.
> Use cases 1, 2, 3, 5, 14 run on their own lab agents (each lab deploys its own SRE Agent).

## Agents

| Lab | Covers | Agent |
|---|---|---|
| `labs/enterprise-operations` | 4, 6, 7, 8, 9, 10, 11, 12, 13 | `sre-eops-lab-b684kg` — https://sre-eops-lab-b684kg--c6405182.daa74423.eastus2.azuresre.ai |
| `labs/zava-learning` | 1, 2 (and 11 alt) | that lab's SRE Agent portal (shown after `azd up`) |
| `labs/vm-cosmosdb` | 3, 5 | that lab's SRE Agent portal (shown after `azd up`) |
| `labs/starter-lab` | 14 | `sre-agent-tlwg3rnc5h6pm` — https://sre-agent-tlwg3rnc5h6pm--9baa2d20.bc75887b.eastus2.azuresre.ai |

## One-time setup (do this ONCE before recording — not between demos)

```powershell
cd labs\enterprise-operations
.\scripts\Configure-SreAgent.ps1                                                                 # base skills, connectors, tasks, hook
.\scripts\Add-EntraAuthSkill.ps1                                                                  # UC8 skill + dataset
.\scripts\Install-AgentSkill.ps1 -SkillName capacity-forecast      -SkillPath .\sre-config\skills\capacity-forecast\SKILL.md      -FixturePath .\docs\capacity-forecast-fixture.json   # UC9
.\scripts\Install-AgentSkill.ps1 -SkillName cost-anomaly           -SkillPath .\sre-config\skills\cost-anomaly\SKILL.md           -FixturePath .\docs\cost-anomaly-fixture.json        # UC11
.\scripts\Install-AgentSkill.ps1 -SkillName security-investigation -SkillPath .\sre-config\skills\security-investigation\SKILL.md                                                       # UC12
.\scripts\Install-AgentSkill.ps1 -SkillName fleet-health           -SkillPath .\sre-config\skills\fleet-health\SKILL.md                                                                 # UC13
```

For UC14, configure the GitHub deployment connection once from `labs\starter-lab`:

```powershell
.\scripts\Setup-GrubifyDeployment.ps1 -Repository shaleen-wonder-ent/grubify
```

This establishes GitHub Actions OIDC, resource-scoped deployment permissions, and repository values. The starter lab's post-provision step installs the `grubify-pr-delivery` skill, `incident-handler`, response plan, and write-approval hook.

After this, UC 8, 9, 11, 13 need **no per-demo setup**. UC 4, 6, 7, 10, 12 need one quick seed command each (below). UC14 needs the vulnerable application state described below.

---

## The 14 demos

All EO commands assume `cd labs\enterprise-operations`. Replace `<BLOCKED>`/`<BLOCKER>` in UC4 with the session IDs printed by Diagnose.

| # | Use case | Agent / target | Setup (you run in PowerShell) | Prompt to paste in SRE Agent (new thread) | Highlight in output |
|---|----------|----------------|-------------------------------|-------------------------------------------|---------------------|
| 1 | Application outage RCA | Zava Learning agent | `pwsh .\chaos\break-app.ps1` (from `labs\zava-learning`) — drops the quiz service to zero replicas | `Investigate the outage affecting the Zava Learning quiz launch over the last 30 minutes. Correlate Application Insights, Log Analytics, Azure Monitor alerts, and deployment history. Build a UTC timeline, rank hypotheses, name the leading root cause and confidence, and recommend the least disruptive mitigation. Read-only.` | Names the **quiz/assessment tier** and the **scale-to-zero** change; does not blame app code for every 5xx |
| 2 | Connectivity (hub↔spoke↔internet) | Zava Learning agent | `pwsh .\chaos\break-nsg.ps1` (from `labs\zava-learning`) — injects an NSG deny rule | `Diagnose connectivity from the App Gateway to the internal apps subnet for the last 30 minutes. Trace DNS, effective NSG and routes, App Gateway backend health, and the destination listener. Return a hop table, identify the first failing hop, and propose the smallest correction without changing routes, NSGs, or DNS. Read-only.` | Finds the **NSG deny rule** as the first failing hop; rejects a healthy hop |
| 3 | VM & infrastructure incident | vm-cosmosdb agent | `bash scripts/break-vm.sh cpu` (from `labs\vm-cosmosdb`) — CPU stress on `vm-sap-app-01` | `Investigate the incident on VM vm-sap-app-01 over the last 30 minutes. Check Resource Health, power state, CPU/memory, disk, network, and Activity Log. Correlate control-plane and guest evidence into a UTC timeline, name the probable cause and confidence, and recommend least-disruptive actions. Do not restart or resize without approval.` | Attributes **sustained CPU** from guest + control-plane evidence; restart is a gated mitigation, not the diagnosis |
| 4 | SQL MI performance | EO agent | `.\scripts\Invoke-SqlMiDemo.ps1 -Action Fault -DurationSeconds 600 -ApproveWrite` then `.\scripts\Invoke-SqlMiDemo.ps1 -Action Diagnose` (note the `session_id` / `blocking_session_id`) | `Analyze performance for SQL Managed Instance sqlmi-lab-b684kg / database sre_demo for the last 15 minutes. Blocked session <BLOCKED> waits on LCK_M_X (UPDATE); blocker <BLOCKER> is suspended in WAITFOR; Query Store query_id 18 ~18.9 ms, 883 reads. Rank bottlenecks, separate observed from inferred, disclose the short baseline, redact statement text, recommend the least disruptive fix, and perform no writes.` | **Lock contention ranked #1**; CPU/IO/storage/platform explicitly ruled out; no scaling recommended |
| 5 | VM availability (30 days) | vm-cosmosdb agent | `bash scripts/configure-availability-demo.sh` (from `labs\vm-cosmosdb`) — loads the availability skill + 30-day data | `Create a VM availability report for all VMs in this lab for the 30 complete days ending today. Define the availability formula and sampling interval, report available/unavailable/unknown/excluded minutes per VM, compare to a 99.9% target, and flag retention gaps. This is read-only.` | Reports **unknown time separately**; refuses a 30-day claim if retention is shorter |
| 6 | Resources added/removed (7 days) | EO agent | `.\scripts\Seed-ResourceLifecycle.ps1` | `Inventory Azure resources created, deleted, moved, or materially modified in resource group rg-eops-uc6-lifecycle during the last seven days. Query Activity Log and Resource Graph. Return separate Added/Removed/Moved/Modified tables, deduplicate child operations, attribute callers, and flag changes missing the change-ticket tag. Read-only.` | Lists the **deleted route table from Activity Log** (absent in Resource Graph) and flags the **missing-tag** resource |
| 7 | Everything changed (24 h) | EO agent | `.\scripts\Seed-ChangeDigest.ps1` | `Build a unified UTC change timeline for resource group rg-eops-uc6-lifecycle over the last 24 hours: resource writes/deletes, deployments, NSG/route changes, and RBAC/policy changes. Group child operations by correlation/deployment ID, rank by operational impact, and flag failed or suspicious changes. Do not claim causality from timing alone. Read-only.` | One deduplicated timeline; **flags the FAILED deployment** and the **RBAC** + **NSG** changes as higher risk |
| 8 | Entra authentication | EO agent | *(none — installed in one-time setup)* | `Use the entra-authentication skill. Investigate authentication failures for Zava Inventory Sync and Zava Operations Portal from 2026-08-24T07:00:00Z to 2026-08-24T11:00:00Z. Aggregate by result code and principal, redact PII and IPs, classify each cluster (auth/token/Conditional Access/consent/RBAC), correlate preceding credential/CA changes, and recommend safe fixes. Read-only.` | Correlates the **secret rotation → invalid-secret spike** (~95%) and the **CA policy edit → device-compliance blocks** |
| 9 | Capacity exhaustion forecast | EO agent | *(none — installed in one-time setup)* | `Use the capacity-forecast skill. Forecast capacity exhaustion for the Zava Orders SQL database over the next 21 days using the daily history available. Assess data quality, report current/limit/headroom/growth/forecast range/confidence per dimension, model weekly seasonality where supported and forecast the seasonal peak, rank the dimension closest to exhaustion, and distinguish resource limit from quota. Read-only.` | **Storage critical in ~2 days** (R²≈1.0); connections modeled with **weekly seasonality**; **resource limit ≠ quota** |
| 10 | Failed deployment investigation | EO agent | `.\scripts\Seed-DeploymentFaults.ps1` | `Failed deployment investigation for resource group rg-eops-uc6-lifecycle over the last 3 hours. Identify the first failing operation and error code for each, distinguish control-plane failures from runtime regressions, preserve the last known good deployment, and recommend fixes with approval gates. Read-only.` | **First failing op + error code** per deployment; **last-known-good preserved**; states **no runtime regression** |
| 11 | Cost anomaly detection | EO agent | *(none — installed in one-time setup)* | `Use the cost-anomaly skill. Detect cost anomalies for this subscription over the last 7 days vs the prior baseline. Prefer live Cost Management; if unavailable, use the provided dataset and label it an estimate with its freshness lag. Rank drivers by absolute impact, correlate the top driver with deployment changes, separate new-resource cost from a true anomaly, project monthly impact, and give read-only savings recommendations.` | **SQL Managed Instance = dominant driver**; figures labeled **estimate, not billed**; correlates the real deployment |
| 12 | Security incident investigation | EO agent | `.\scripts\Seed-SecurityIncident.ps1` (opens inbound RDP) — restore later with `-Cleanup` | `Security incident investigation for resource group rg-eops-uc6-lifecycle over the last 2 hours — a suspected NSG rule change. Attribute the change (who/when/where), identify the rule and port/protocol/source, scope blast radius from association and reachability, decide exposure vs compromise, and give approval-gated containment. Read-only.` | Verdict **EXPOSURE, not compromise**; blast radius scoped (**NSG unassociated → zero live traffic**); attribution with truncated IPs |
| 13 | Multi-subscription health | EO agent | *(none — installed in one-time setup)* | `Use the fleet-health skill. Consolidated health overview across three scopes for the last 24 hours: Scope A = rg-sre-eops-lab, Scope B = rg-eops-uc6-lifecycle (subscription 09e7c1cb-53ca-4d05-bcf0-8881c42e680e), Scope C = subscription 11111111-2222-3333-4444-555555555555. Coverage-check each scope first, normalize severity, dedupe, and give one estate status. Do not mark unknown or critical scopes as healthy. Read-only.` | **Scope C reported as a blind spot (Unknown, not green)**; estate status not healthy while a scope is unknown; A healthy vs B degraded |
| 14 | App-centric OOM → fix PR → deploy | Starter Lab agent / Grubify API | Deploy the vulnerable Grubify API state, then run `bash scripts/break-app.sh` from `labs\starter-lab` | *(none — Azure Monitor automatically routes the HTTP 5xx alert to `incident-handler` in autonomous mode)* | Correlates **cart HTTP 5xx + `OutOfMemoryException`** with the unbounded 10 MB allocation; creates a minimal fix PR; a **human merges**; GitHub Actions deploys an immutable SHA image and verifies `/health` |

---

## UC14 — App-centric OOM incident to deployed fix

### Recording precondition

For the complete incident-to-code story, the connected Grubify repository's `main` branch and the deployed image must both contain the intentional defect in `GrubifyApi/Controllers/CartController.cs`: every cart request retains a 10 MB allocation in an unbounded static collection. If `main` already contains the merged fix, deploying an old image will reproduce the OOM alert, but the agent should correctly report **deployment drift / outdated image** instead of opening another meaningful code-fix PR.

### Setup and induce the incident

From `labs\starter-lab`, confirm the app starts healthy, then run:

```powershell
& "C:\Program Files\Git\bin\bash.exe" ".\scripts\break-app.sh"
```

The default run sends 200 cart requests at 0.5-second intervals. On the vulnerable build, successful requests each retain 10 MB until the .NET managed heap is exhausted. Cart requests begin returning HTTP 5xx even if the Container Apps `RestartCount` metric remains zero.

### Record the autonomous response

1. Open https://sre.azure.com → **Activities → Incidents**.
2. Select `[Sev3] alert-http-5xx-srelab-starter`. The alert can fire and resolve quickly, so include closed/recent incidents if it is no longer active.
3. Show the agent correlating Azure Monitor, Application Insights, console logs, and the connected repository.
4. Show the confirmed RCA: `CartController.AddItemToCart` retains a 10 MB `byte[]` per request in a static list with no eviction.
5. Open the agent-created GitHub PR and show that it changes only the defective cart code and includes evidence, validation, rollout, and rollback details.
6. Emphasize the approval boundary: the agent may create the branch and PR, but it must not approve, merge, or deploy.
7. Merge the PR manually and record **Actions → Deploy Grubify API** building `grubify-api:<commit-sha>`, updating the Container App, and validating `/health`.
8. Run `break-app.sh` again. The expected result is 200 successes, zero errors, HTTP 200 health, and **No memory-leak failure detected**.

### Expected timing

- Load generation: about 2–4 minutes.
- Azure Monitor alert and SRE incident: usually within 5–8 minutes.
- Agent investigation and PR creation: about 5–10 minutes after incident ingestion.
- GitHub Actions deployment after human merge: about 3–6 minutes.

---

## Reset / cleanup (after recording)

```powershell
cd labs\enterprise-operations
.\scripts\Invoke-SqlMiDemo.ps1 -Action Reset -ApproveWrite      # UC4: clear the blocking fault
.\scripts\Seed-SecurityIncident.ps1 -Cleanup                    # UC12: restore secure NSG baseline
.\scripts\Seed-DeploymentFaults.ps1 -Cleanup                    # UC6/7/10: delete the seed resource group (also clears UC6/7)
```

Lab agents for UC1/2 restore with the matching `fix-*.ps1` (e.g. `pwsh .\chaos\fix-app.ps1`, `pwsh .\chaos\fix-nsg.ps1`). The vm-cosmosdb CPU stress (UC3) self-clears after 10 minutes.

For UC14, the merged PR is the normal reset: keep the fixed `main` branch and verify `break-app.sh` reports no memory-leak failure. To record the complete PR flow again, deliberately restore the vulnerable code on `main` through a reviewed commit and let the deployment workflow publish that commit before running the load. Do not merely point the Container App at an old vulnerable image when the connected repository already contains the fix; that demonstrates deployment drift, not autonomous code remediation.

## Tips for smooth recording

- Start a **new thread** for every prompt — skills load per thread.
- Seed EO scenarios 4, 6, 7, 10, 12 **~2 minutes before** their prompt so Activity Log ingestion completes (deployment history for UC10 is instant).
- UC 8, 9, 11, 13 are dataset/analysis scenarios with **no live seed** — run them anytime.
- UC14 is event-driven and needs no chat prompt. Keep the incidents view on recent/closed incidents because the agent may close the alert after creating the PR.
- If a prompt returns "agent is busy", wait a few seconds and re-open the thread; the answer is still generating.
