# Azure SRE Agent — Use-Case Catalog (Azure-Native)

**Scope:** This catalog is **100% Azure-centric**. Every scenario is grounded in Azure-native
telemetry, control-plane APIs, and services. Third-party platforms (F5, Palo Alto, Dynatrace,
ServiceNow, PagerDuty, etc.) and on-premises/hybrid connectivity are **intentionally out of scope
for this phase** — they are discussed separately and their parked assets live under [`archive/`](archive/).

> Companion document: [AZURE-SRE-AGENT-DEMO-GUIDE-2026-08-06.md](AZURE-SRE-AGENT-DEMO-GUIDE-2026-08-06.md)
> (product overview, scope model, pricing, and live-demo flow).

## How to read this catalog

- **Azure data sources** — the native signals the agent reads (Activity Log, Azure Resource Graph,
  Azure Monitor metrics/alerts, Log Analytics/KQL, Application Insights, Resource Health, Cost
  Management, Entra sign-in logs, Azure Backup, etc.).
- **Best lab to demo** — the deployable Azure-centric lab in this repo that most directly exercises
  the scenario. See [`labs/`](labs/).
- **Run mode** — start in **Reader / Review**; promote to approved writes only for tested, reversible
  actions.
- **New module?** — flags scenarios that need a capability not yet built as a standalone lab (they
  are delivered through the [`enterprise-operations`](labs/enterprise-operations/) overlay or a small
  add-on).

---

## The 13 scenarios

| # | Scenario | What the SRE Agent does | Primary Azure data sources | Best lab to demo | Run mode |
|---|----------|-------------------------|----------------------------|------------------|----------|
| 1 | **Application outage root cause analysis** | Correlate infrastructure, network, and application telemetry to identify outage causes and remediation actions | **Application Insights**, **Log Analytics**, Azure Monitor alerts, Activity Log, deployment history | [zava-learning](labs/zava-learning/) · [starter-lab](labs/starter-lab/) · [zava-aks-postgres](labs/zava-aks-postgres/) | Review |
| 2 | **Connectivity diagnostics: hub ↔ spoke ↔ internet** | Detect connectivity bottlenecks and provide actionable recommendations for network optimization | **Connection Monitor**, Network Watcher, `AZFW*` firewall logs, NSG/VNet flow logs, effective routes | [zava-aks-postgres](labs/zava-aks-postgres/) (hub-spoke + Azure Firewall) · [zava-learning](labs/zava-learning/) (App Gateway → NSG → ACA) | Review |
| 3 | **VM & infrastructure incident investigation** | Rapidly determine probable root cause of infrastructure issues and generate a summarized incident report | Azure **Monitor alert**, VM Insights, `InsightsMetrics`/`Perf` (KQL), Activity Log | [vm-cosmosdb](labs/vm-cosmosdb/) (VM perf-drift lab) | Review |
| 4 | **Azure SQL Managed Instance performance analysis** | Identify performance bottlenecks and optimization opportunities to improve database efficiency | SQL MI metrics, **Query Performance Insight**, `AzureDiagnostics`/`AzureMetrics` (KQL) | [enterprise-operations](labs/enterprise-operations/) (**SQL MI module**) | Reader |
| 5 | **VM availability report (past 30 days)** | Track VM uptime and availability trends for SLA validation and reliability reporting | **Resource Health**, Azure Monitor VM metrics, `Heartbeat`/`AzureActivity` in Log Analytics | [vm-cosmosdb](labs/vm-cosmosdb/) · [public-port-guard](labs/public-port-guard/) (VMs) | Reader |
| 6 | **Services / resources added or removed (past week)** | Gain visibility into newly deployed, modified, and deleted resources to strengthen governance and operational control | Azure **Activity Log**, Azure **Resource Graph** (cross-subscription) | [enterprise-operations](labs/enterprise-operations/) (multi-sub) · [deployment-compliance](labs/deployment-compliance/) | Reader |
| 7 | **Show everything changed in last 24 h** | Quickly identify configuration, infrastructure, security, and resource changes to accelerate troubleshooting and change reviews | Azure **Activity Log**, Azure **Resource Graph**, resource change history | [deployment-compliance](labs/deployment-compliance/) | Reader |
| 8 | **Entra authentication troubleshooting** | Investigate authentication issues and provide a consolidated view of login failures, lockouts, and access problems | **Microsoft Entra** sign-in & audit logs (`SigninLogs`, `AuditLogs`), Conditional Access telemetry, Entra diagnostic settings → Log Analytics | [enterprise-operations](labs/enterprise-operations/) (**Entra telemetry module**) | Reader |
| 9 | **Capacity exhaustion prediction** | Predict resource constraints before service impact and recommend proactive remediation actions | Azure Monitor metrics, `InsightsMetrics`/`Perf`, storage & DB metrics, trend/forecast over KQL | [enterprise-operations](labs/enterprise-operations/) (forecast) · [vm-cosmosdb](labs/vm-cosmosdb/) · [zava-aks-postgres](labs/zava-aks-postgres/) | Reader |
| 10 | **Failed deployment investigation** | Identify deployment-related changes, configuration drift, and likely causes of service degradation | Azure **Activity Log** (deployments), Resource Graph, IaC/state comparison, App Insights | [deployment-compliance](labs/deployment-compliance/) · [zava-learning](labs/zava-learning/) (IaC break/fix) | Review |
| 11 | **Azure cost anomaly detection** | Detect unexpected cost spikes, determine contributing factors, and recommend optimization opportunities | **Cost Management** (cost/usage), Activity Log (scale/create events), Advisor cost recommendations | [zava-learning](labs/zava-learning/) (weekly cost auditor) · [enterprise-operations](labs/enterprise-operations/) (FinOps) | Reader |
| 12 | **Security incident investigation** | Establish an event timeline, identify impacted assets, and accelerate security investigations | Azure **Activity Log**, **Defender for Cloud** alerts, NSG/firewall changes, public-exposure signals, `SecurityAlert` (KQL) | [public-port-guard](labs/public-port-guard/) · [starter-lab](labs/starter-lab/) (public-exposure auditor) · [deployment-compliance](labs/deployment-compliance/) | Review |
| 13 | **Multi-subscription operational health overview** | Provide a consolidated view of health, incidents, risks, and recommendations across Azure environments in the same Microsoft Entra tenant | Resource Graph (cross-sub), Resource Health, Azure Monitor, Advisor, Activity Log — one agent, multiple scopes | [enterprise-operations](labs/enterprise-operations/) (multi-subscription scope) | Reader |

> **Scenario 8 uses Microsoft Entra ID** (sign-in / audit logs and Conditional Access), not on-prem
> Active Directory. Entra diagnostic logs must be routed to a Log Analytics workspace the agent can query.
>
> **Scenario 13 is scoped to subscriptions in one Microsoft Entra tenant.** Grant the agent identity
> read access on each selected subscription. Cross-tenant delegation with Azure Lighthouse is a valid
> product pattern, but it is intentionally outside this reusable lab's automated scope.

---

## What to deploy, by coverage

Pick the smallest set of labs that covers the scenarios you want to demonstrate.

| Lab | Scenarios it best covers | Core Azure resources |
|-----|--------------------------|----------------------|
| [starter-lab](labs/starter-lab/) | 1, 12 | Container Apps, Log Analytics, App Insights, 5xx alert, SRE Agent |
| [zava-learning](labs/zava-learning/) | 1, 2, 10, 11 | App Gateway, Container Apps, PostgreSQL, VNet/NSG, alerts, SRE Agent |
| [zava-aks-postgres](labs/zava-aks-postgres/) | 1, 2, 9 | AKS (private), PostgreSQL, Azure Firewall, hub-spoke VNets |
| [vm-cosmosdb](labs/vm-cosmosdb/) | 3, 5, 9 | Linux VMs, Cosmos DB, Log Analytics, perf alerts |
| [public-port-guard](labs/public-port-guard/) | 5, 12 | VMs, NSG, Activity Log alerts, approval-gated remediation |
| [deployment-compliance](labs/deployment-compliance/) | 6, 7, 10 | Container App, SQL, Activity Log compliance skill |
| [enterprise-operations](labs/enterprise-operations/) *(overlay)* | 4, 6, 8, 9, 13 | SQL MI, Entra telemetry, capacity/forecast, multi-subscription scope |

### Modules still to build (delivered via `enterprise-operations` or a small add-on)

- **Scenario 4** — Azure SQL **Managed Instance** telemetry + query connector.
- **Scenario 8** — **Microsoft Entra** diagnostic logs (`SigninLogs`, `AuditLogs`) → Log Analytics.
- **Scenario 13** — cross-**subscription** RBAC scope for one agent (Reader across selected subs).

These are the only scenarios that require new Azure resources beyond the existing labs; everything
else reuses telemetry and workloads already deployed by the labs above.

---

## Deployment principles (recap)

Preview or deploy a scenario selection from the repository root:

```powershell
pwsh ./Deploy-SreAgentLabs.ps1 -Scenarios '2,4,7,10' -PlanOnly
pwsh ./Deploy-SreAgentLabs.ps1 -Scenarios '2,4,7,10'
```

The launcher uses one canonical lab per scenario, removes duplicate lab deployments, and presents
scenarios 4, 8, and 13 as guided enterprise steps where tenant-specific input is still required.

- **One agent, many scopes.** The agent's operational reach is set by the Azure RBAC granted to its
  managed identity, not by where the agent resource lives. Start with **Reader** on the target
  resource groups / subscriptions.
- **Reader-first, Review-mode.** Demonstrate read-only investigations first; enable approved,
  reversible writes only for tested use cases (scenarios 1, 2, 3, 10, 12).
- **Reuse telemetry.** Prefer native metrics, Activity Log, Resource Health, and existing
  Log Analytics / Application Insights before ingesting new data.
- **Third-party & on-prem** — parked under [`archive/`](archive/) and discussed manually; not part of
  this Azure-native catalog.
