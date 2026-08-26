<!--
Table styling note: rendered in GitHub/most viewers with default table CSS.
For slide export, the per-use-case tables map 1:1 to a signal/cost matrix.
-->

# Azure SRE Agent — Telemetry Cost & Consumption Evidence

**Audience:** Platform engineering, cloud operations, FinOps, and leadership
**Purpose:** Show that each Azure SRE Agent use case can be built primarily from Azure-native,
no-incremental-cost signals — and that Log Analytics (LAW) ingestion is introduced **selectively**,
only where it adds real value.

> **Core message:** Azure SRE Agent does **not** require every Azure diagnostic log to be ingested
> into Log Analytics. Each use case starts with Azure-native metrics, Activity Log, Resource Health,
> Resource Graph, service APIs, and existing licensed telemetry. Log Analytics is introduced
> selectively only where historical KQL correlation, guest telemetry, application traces, centralized
> alerting, or extended retention is required.

The purpose is **not just to list telemetry**, but to show that each use case is built from a
combination of:

1. **Azure-native signals** already available at no incremental monitoring cost.
2. **Signals included** with an existing Azure service or license.
3. **Optional telemetry** that becomes consumption-chargeable only when enabled.
4. **Selective Log Analytics ingestion**, rather than sending every available log to LAW.

Azure automatically collects standard platform metrics and the Azure Activity Log without Azure
Monitor ingestion charges. Resource logs, guest OS logs, Application Insights telemetry, VM Insights
data, and other diagnostic data normally require explicit enablement and may generate ingestion,
retention, alert, or query charges.
([Azure Monitor pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/),
[Cost & usage](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/cost-usage),
[Diagnostic settings](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/diagnostic-settings))

This aligns with the internal telemetry position: use native metrics, Activity Log,
Resource Health, and live configuration first; reuse existing observability; and treat LAW as a
**selective correlation store rather than a universal log sink**. *(Internal position — SRE Agent
telemetry strategy.)*

---

## Classification legend

Use these four labels on the slides. The **color** shows the cost posture at a glance:

| Color | Label | Meaning |
|---|---|---|
| 🟢 | **Native / default** | Available directly from Azure without sending data to LAW — no additional telemetry cost. |
| 🟡 | **Existing service or license** | No new LAW ingestion, but the underlying service or license may already carry a charge. |
| 🟡 | **Optional, consumption-based** | Becomes chargeable when monitoring, diagnostic collection, alerts, API retrieval, or extended retention is enabled. |
| 🔴 | **LAW ingestion** | Charged primarily according to data ingested and retained in Log Analytics. |

> **Color key:** 🟢 native / no additional telemetry cost · 🟡 optional or license/plan-dependent charge · 🔴 Log Analytics ingestion (ingestion + retention charge).
>
> **Important:** "Free" means **no additional telemetry ingestion cost** — not that the underlying
> Azure resource itself is free.

---

## Use Case 1 — Application outage RCA

| Signal | What it provides | Cost classification |
|---|---|---|
| **Application Insights** | Request failures, response time, dependency calls, exceptions, availability results, app traces — determines whether the outage began in code, a dependency, or infrastructure. | 🔴 **Optional, consumption-based / LAW ingestion** — workspace-based App Insights data is stored in LAW and charged by ingestion/retention; use sampling. |
| **Log Analytics / KQL** | Cross-source querying and correlation across application, resource, OS, and platform data. | 🔴 **LAW ingestion** — KQL is not the main cost; ingested/retained volume is. Basic/Auxiliary tables may add query charges. ([cost-logs](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs)) |
| **Azure Monitor alerts** | Which alert fired, when the condition started, affected resource, state, severity — the incident starting point. | 🟡 **Potentially chargeable** — depends on signal, evaluation frequency, dimensions, and notifications. |
| **Activity Log & deployment history** | Subscription-level control-plane operations: deployment, scale, config update, restart, deletion. | 🟢 **Native / default** — auto-collected; inspect directly without LAW. |

> **Cost-conscious position:** Start with Activity Log, deployment history, standard metrics, alert
> context, and **sampled** App Insights failures/dependencies. Enable verbose traces only during
> investigation or for critical apps.

---

## Use Case 2 — Connectivity diagnostics

| Signal | What it provides | Cost classification |
|---|---|---|
| **Connection Monitor & Network Watcher** | Endpoint-to-endpoint reachability, latency, and path issues. | 🟡 **Potentially chargeable** — estimate by selected feature and monitoring frequency. |
| **Effective NSG rules & effective routes** | The configuration Azure currently applies to a NIC (route selection, security-rule evaluation). | 🟢 **Native configuration / no LAW required** — queryable directly via Azure APIs. |
| **Azure Firewall logs & NSG/VNet flow logs** | Allowed/denied traffic, rule matches, source/destination, flow behaviour. | 🔴 **Optional, potentially high-volume ingestion** — enable only required categories. |
| **Application Gateway backend health** | Whether App Gateway can reach backends and health probes succeed. | 🟢 **Native health state** for initial diagnosis; detailed logs need diagnostic settings (ingestion). |

> **Cost-conscious position:** Start with effective NSG rules, effective routes, peering state,
> backend health, DNS config, and listener status. Use Firewall/flow logs only when
> configuration-level evidence does not explain the issue.

---

## Use Case 3 — VM and infrastructure incident

| Signal | What it provides | Cost classification |
|---|---|---|
| **Resource Health & VM power state** | Platform issue, maintenance, unexpected host event, or availability problem. | 🟢 **Native / default** — first evidence before guest telemetry. |
| **VM Insights, Perf, InsightsMetrics** | CPU, memory, disk, process, network, guest performance. | 🔴 **Optional / LAW ingestion** — volume depends on DCR, counters, interval, VM count. |
| **Heartbeat** | Whether the Azure Monitor Agent still communicates with the workspace. | 🔴 **LAW ingestion** — lightweight per record, but adds up at scale. |
| **Guest OS event logs & Syslog** | OS errors, service failures, auth events, kernel/app messages. | 🔴 **Optional, potentially high-volume LAW ingestion** — don't collect all channels/facilities by default. |

> **Cost-conscious position:** Minimum = Resource Health, VM power state, standard CPU/disk/network
> metrics, Activity Log, and Heartbeat (if already enabled). Add selected counters and critical event
> channels only where deeper guest diagnosis is needed.

---

## Use Case 4 — SQL Managed Instance performance

| Signal | What it provides | Cost classification |
|---|---|---|
| **SQL MI platform metrics** | CPU, storage, IO, connection, worker, resource utilization. | 🟢 **Native / default** for standard metrics; REST API retrieval and configured alerts can add charges. |
| **Query Store & read-only DMVs** | Query behaviour, waits, blocking sessions, execution stats, plans, engine state. | 🟢 **Existing SQL MI capability** — no LAW ingestion if queried directly and safely. |
| **Query Performance Insight** | Query Store–based views of expensive/regressed queries. | 🟢 **Existing SQL capability** — processed within the SQL service, not copied to LAW. |
| **AzureDiagnostics / AzureMetrics in LAW** | Historical KQL analysis and cross-service correlation. | 🔴 **Optional LAW ingestion** — send only required SQL categories. |

> **Cost-conscious position:** Prefer direct SQL MI metrics, Query Store, and safe DMVs. Use LAW for
> long-term cross-service correlation, centralized alerting, or historical reporting.

---

## Use Case 5 — VM availability report

| Signal | What it provides | Cost classification |
|---|---|---|
| **Resource Health** | Platform-reported unavailable/degraded periods. | 🟢 **Native / default** |
| **Standard VM metrics** | Observed availability-related platform signals. | 🟢 **Native / default** |
| **Heartbeat** | Guest-monitoring continuity; periods the agent/OS was unreachable. | 🔴 **LAW ingestion** |
| **Activity Log** | Starts, stops, restarts, redeployments, management operations. | 🟢 **Native / default** |

> **Cost-conscious position:** A basic report needs only Resource Health, Activity Log, and standard
> metrics. Heartbeat adds guest-level availability but should not imply collecting every guest log.

---

## Use Case 6 — Resources added, modified, or removed

| Signal | What it provides | Cost classification |
|---|---|---|
| **Azure Activity Log** | Control-plane resource lifecycle operations and initiating identity. | 🟢 **Native / default** |
| **Azure Resource Graph** | Current cross-subscription inventory and state comparison. | 🟢 **Azure-native query / no LAW required** |
| **Deployment & correlation IDs** | Group multiple Activity Log events into one operation. | 🟢 **Native control-plane metadata** |

> **Cost-conscious position:** Largely implementable **without LAW** by querying Activity Log and
> Resource Graph directly.

---

## Use Case 7 — Daily operational health summary

| Signal | What it provides | Cost classification |
|---|---|---|
| **Azure Monitor alerts** | Active and recently resolved alerts. | 🟡 **Potentially chargeable** |
| **Resource Health & Service Health** | Resource-specific and Azure service-level health events. | 🟢 **Native Azure health signals** |
| **Activity Log & Resource Graph** | Recent changes plus current inventory. | 🟢 **Native / no LAW required** |
| **Log Analytics operational signals** | Guest, application, and custom operational evidence. | 🔴 **Optional LAW ingestion** |

> **Cost-conscious position:** Generate the core summary from native sources. Query LAW only for
> workloads already onboarded, or when guest/application evidence is required.

---

## Use Case 8 — Entra authentication troubleshooting

| Signal | What it provides | Cost classification |
|---|---|---|
| **Entra sign-in logs** | User/SP/MI/app/resource, auth result, failure code. | 🟢 **Included per Entra licensing/native retention** — Free = 7 days; P1/P2 = 30 days; longer needs export. ([data retention](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/reference-reports-data-retention)) |
| **Conditional Access outcomes** | Which policies applied, succeeded, failed, or were not applied. | 🟡 **License-dependent Entra capability** |
| **Identity Protection risk signals** | Risky sign-ins and risky identities. | 🟡 **Entra licensing dependent** |
| **Export to LAW** | Longer retention and KQL correlation with infra/app events. | 🔴 **Optional LAW ingestion** |

> **Cost-conscious position:** For recent troubleshooting, query Entra directly. Export to LAW only
> for extended retention, centralized correlation, or specific security detections.

---

## Use Case 9 — Capacity forecasting

| Signal | What it provides | Cost classification |
|---|---|---|
| **Azure Monitor standard metrics** | CPU, memory (where available), storage, throughput, connection, utilization trends. | 🟢 **Native / default** |
| **Quota & SKU limits** | Current limits and usage per applicable service. | 🟢 **Native service information** |
| **Historical consumption trends** | From Azure Monitor metrics, existing monitoring, or LAW. | 🟡 **Depends on retention source** |
| **Resource inventory** | Type, SKU, region, size, configuration. | 🟢 **Resource Graph — no LAW required** |

> **Cost-conscious position:** Use platform metrics and Resource Graph first. LAW is needed only for
> guest metrics, custom counters, or retention longer than the native service provides.

---

## Use Case 10 — Deployment health and change correlation

| Signal | What it provides | Cost classification |
|---|---|---|
| **Deployment history & Activity Log** | What changed, when, and which identity/pipeline initiated it. | 🟢 **Native / default** |
| **Application Insights failures & dependencies** | Whether errors/dependency latency increased after deployment. | 🔴 **Optional, consumption-based ingestion** |
| **Azure Monitor metrics** | Before-and-after performance comparison. | 🟢 **Native / default** (standard metrics) |
| **Resource configuration changes** | Via Resource Graph, ARM configuration, change records. | 🟢 **Native query capability** |

> **Cost-conscious position:** Use deployment history, Activity Log, configuration, and standard
> metrics first. Include **sampled** application failures rather than full trace ingestion.

---

## Use Case 11 — Cost anomaly investigation

| Signal | What it provides | Cost classification |
|---|---|---|
| **Azure Cost Management** | Cost/usage, budgets, trends, cost analysis. | 🟢 **No additional Cost Management charge** to Azure customers. ([pricing](https://azure.microsoft.com/en-us/pricing/details/cost-management/)) |
| **Resource Graph inventory** | Which resources exist, SKU, region, tags, configuration. | 🟢 **Native / no LAW required** |
| **Standard utilization metrics** | Whether increased spend matches actual utilization. | 🟢 **Native standard metrics** |
| **Activity Log & deployment history** | Scale actions, new resources, SKU changes, deployments. | 🟢 **Native / default** |

> **Cost-conscious position:** Normally requires **little or no additional LAW ingestion**.

---

## Use Case 12 — Security investigation

| Signal | What it provides | Cost classification |
|---|---|---|
| **Defender for Cloud findings** | Recommendations, alerts, posture findings, affected resources. | 🟡 **Plan/workload dependent** — consume existing findings rather than duplicating telemetry. |
| **Activity Log & Resource Graph** | Control-plane changes and current exposure. | 🟢 **Native / default** |
| **NSG, public IP, network configuration** | Whether a resource allows public/broad access. | 🟢 **Native configuration query** |
| **Key Vault audit & resource logs** | Vault operations and access activity. | 🔴 **Optional diagnostic logs / potentially LAW ingestion** |

> **Cost-conscious position:** Use Defender findings, Resource Graph, and live configuration first.
> Ingest only high-value audit/security events needed for correlation.

---

## Use Case 13 — Multi-subscription fleet health

| Signal | What it provides | Cost classification |
|---|---|---|
| **Azure Resource Graph** | Fleet-wide inventory and configuration. | 🟢 **Native / no LAW required** |
| **Resource Health & Azure Monitor metrics** | Availability and utilization indicators. | 🟢 **Native standard signals** |
| **Azure Policy & security findings** | Governance compliance and security posture. | 🟡 **Policy evaluation is native**; security may depend on Defender plans. |
| **Cost & capacity context** | Via Cost Management, quotas, Resource Graph, standard metrics. | 🟢 **Mostly native** |

> **Cost-conscious position:** Query each native control-plane service directly. Avoid centralizing
> every subscription's detailed resource logs into one LAW just to build the fleet overview.

---

## Use Case 14 — Deployment compliance monitoring

| Signal | What it provides | Cost classification |
|---|---|---|
| **Activity Log deployment events** | Operation, timestamp, resource, caller, result. | 🟢 **Native / default** |
| **Caller identity & `claims.appid`** | Whether initiated by approved CI/CD, an admin, CLI, or another app. | 🟢 **Native event metadata** |
| **Container App revision & configuration** | Active revision, image, scaling, ingress, deployment config. | 🟢 **Native resource configuration** |
| **Approved pipeline / policy context** | Expected deployment method to compare against. | 🟢 **Existing governance / DevOps context** |
| **Optional detailed Container App logs** | Console/system logs to assess impact after a non-compliant deploy. | 🔴 **Optional LAW ingestion** |

> **Cost-conscious position:** Classify compliance primarily from Activity Log, caller identity,
> deployment metadata, and live configuration. Query container logs only if the deployment also
> caused an application issue.

---

## Core message

> **Azure SRE Agent does not require every Azure diagnostic log to be ingested into Log Analytics.**
> Each use case starts with Azure-native metrics, Activity Log, Resource Health, Resource Graph,
> service APIs, and existing licensed telemetry. Log Analytics is introduced selectively only where
> historical KQL correlation, guest telemetry, application traces, centralized alerting, or extended
> retention is required.

This is technically important because:

- Platform metrics and the Activity Log are automatically collected and available without LAW
  ingestion charges.
  ([Azure Monitor pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/),
  [Cost & usage](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/cost-usage))
- Resource logs are generally **not** collected by default and require diagnostic settings.
  ([Diagnostic settings](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/diagnostic-settings))
- Sending data to LAW introduces ingestion and potentially retention charges.
  ([cost-logs](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs),
  [Cost & usage](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/cost-usage))
- Diagnostic settings allow individual log categories to be selectively enabled or disabled, so you
  do not need an "all logs" configuration.
  ([Diagnostic settings FAQ](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/diagnostic-settings-faq))
- Cost Management is available to Azure customers at no additional Cost Management charge.
  ([Cost Management pricing](https://azure.microsoft.com/en-us/pricing/details/cost-management/))

---

## References

| # | Source |
|---|---|
| 1 | [Azure Monitor pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/) |
| 2 | [Azure Monitor cost and usage](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/cost-usage) |
| 3 | [Diagnostic settings in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/diagnostic-settings) |
| 4 | [Diagnostic settings FAQ](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/diagnostic-settings-faq) |
| 5 | [Azure Monitor Logs cost calculations and options](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs) |
| 6 | [Entra ID monitoring — data retention](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/reference-reports-data-retention) |
| 7 | [Entra ID sign-in logs](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/concept-sign-ins) |
| 8 | [Azure Cost Management pricing](https://azure.microsoft.com/en-us/pricing/details/cost-management/) |

> **Companion docs:** [AZURE-SRE-AGENT-USE-CASES.md](AZURE-SRE-AGENT-USE-CASES.md) (Azure-native
> use-case catalog) and [AZURE-SRE-AGENT-DEMO-GUIDE-2026-08-06.md](AZURE-SRE-AGENT-DEMO-GUIDE-2026-08-06.md)
> (product overview, scope model, and live-demo flow).
