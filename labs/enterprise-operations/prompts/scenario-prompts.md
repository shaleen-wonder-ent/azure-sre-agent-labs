# Enterprise Operations Prompt Pack

Replace every `@@...@@` placeholder before use. These prompts assume the permissions, telemetry, and
knowledge described in the parent [lab blueprint](../README.md). Start with the investigation prompt
in chat. Use scheduled variants only after the interactive result is accurate and repeatable.

## Prompt rules

- Use UTC for every query and timeline.
- Name every source queried and disclose missing data or denied permissions.
- Treat an empty result as “no evidence in this source and window,” not proof that nothing happened.
- Separate facts from inference and give confidence for the leading conclusion.
- Do not make changes unless the prompt explicitly requests a proposal and an approval gate succeeds.
- Do not expose tokens, credentials, sign-in details, query text containing PII, or sensitive security data.

## 1. Application outage root cause analysis

**Interactive prompt**

```text
Investigate the application outage affecting @@APPLICATION@@ in @@RESOURCE_GROUP@@ from
@@START_UTC@@ to @@END_UTC@@. Work from the user-visible symptom toward the cause. Correlate
Application Insights requests, dependencies and exceptions; Log Analytics logs; Azure Monitor
metrics and alerts; resource health and configuration; network path state; and Activity Log plus
deployment history.

Build a UTC evidence timeline before naming a cause. Rank the plausible hypotheses, state the
leading root cause and confidence, and show which evidence supports or contradicts each hypothesis.
Distinguish the triggering event from latent contributing factors. Recommend the least disruptive
mitigation and a durable prevention action, but do not perform a write. Finish with the standard
report schema and explicitly list telemetry or permission gaps.
```

**Acceptance:** identifies the affected tier, onset time, causal change or failure, blast radius, and
recovery signal without assuming that every HTTP 5xx is an application-code defect.

## 2. Connectivity diagnostics between hub, spoke, and internet

**Interactive prompt**

```text
Diagnose connectivity from @@SOURCE_RESOURCE@@ in spoke @@SPOKE_VNET@@ through hub @@HUB_VNET@@ to
@@DESTINATION@@ during @@START_UTC@@ to @@END_UTC@@. Trace every hop: DNS, NIC and effective NSG,
effective routes and UDRs, peering, Virtual WAN or Azure Firewall if present, load balancer or
Application Gateway health, private endpoint policy, and destination listener/health.

Use Network Watcher Connection Troubleshoot, Connection Monitor history, Network Verifier when
available, flow/firewall logs, and Activity Log changes. Return a path table with hop, expected next
hop, observed state, blocking control, and evidence. Identify the first failing hop and distinguish
DNS, routing, policy, transport, and application failures. Propose the smallest correction but do not
change routes, peerings, firewall policy, NSGs, or DNS without approval.
```

**Acceptance:** finds the planted path fault and rejects at least one plausible but healthy hop.

## 3. VM and infrastructure incident investigation

**Interactive prompt**

```text
Investigate the incident affecting VM @@VM_NAME@@ in @@RESOURCE_GROUP@@ during @@START_UTC@@ to
@@END_UTC@@. Check Azure Resource Health and power state, VM and guest heartbeat, CPU and memory,
disk capacity/latency/queue, network throughput and drops, boot diagnostics, guest/application logs,
extensions, effective NSG/routes, platform maintenance, and Activity Log changes.

Correlate control-plane and guest evidence into a UTC timeline. Identify the probable root cause,
affected services, and confidence. State whether the evidence points to platform, configuration,
capacity, guest OS, process, disk, or network failure. Recommend least disruptive actions first.
Do not restart, resize, redeploy, detach disks, or run a guest command without approval. Produce the
standard incident report with a verification check for the original symptom.
```

**Acceptance:** does not recommend restart as the diagnosis; restart may be a gated mitigation only.

## 4. Azure SQL Managed Instance performance analysis

**Interactive prompt**

```text
Analyze performance for SQL Managed Instance @@SQL_MI@@ and database @@DATABASE@@ during
@@START_UTC@@ to @@END_UTC@@. Correlate Azure Monitor resource metrics with Query Store and safe,
read-only DMV evidence for waits, blocking chains, long-running requests, deadlocks, query duration,
CPU, data/log IO, storage utilization, worker/session pressure, tempdb pressure, and recent
configuration or deployment changes.

Compare the incident window with the prior @@BASELINE_DAYS@@-day baseline. Rank the top bottlenecks
by impact and identify whether the dominant cause is query plan/index, blocking, compute, IO,
storage, connection/session, or platform health. Include query identifiers and aggregated metrics,
but redact statement text that may contain sensitive values. Recommend query/index/configuration or
scale actions with expected benefit and risk. Do not kill sessions, change indexes/configuration, or
scale the instance without approval.
```

**Acceptance:** identifies blocking or the seeded expensive query from SQL evidence and does not infer
database pressure solely from application latency.

## 5. VM availability report for the past 30 days

**Interactive prompt**

```text
Create a VM availability report for all VMs in @@SCOPE@@ for the 30 complete days ending
@@END_UTC@@. Use VM availability metrics or heartbeat, Resource Health events, power-state and
Activity Log events, planned maintenance, and configured availability tests. Define the availability
formula and sampling interval before calculating results.

For each VM report total observed minutes, available minutes, unavailable minutes, unknown/no-data
minutes, planned exclusions, availability percentage, longest outage, outage count, and top causes.
Do not count unknown telemetry as available. Compare results with target @@SLO_PERCENT@@ and flag
retention or onboarding gaps. Provide fleet summary, per-VM table, outage timeline, and methodology.
This is read-only.
```

**Scheduled-task prompt**

```text
Generate the rolling 30-day VM availability report for @@SCOPE@@ using the approved availability
methodology. Separate unavailable from unknown time, compare each VM with @@SLO_PERCENT@@, rank SLO
breaches, and post a concise fleet summary plus the downloadable report. Read-only; do not remediate.
```

**Acceptance:** reports unknown time separately and refuses a 30-day claim when retention is shorter.

## 6. Services or resources added or removed in the past week

**Interactive prompt**

```text
Inventory Azure resources created, deleted, moved, or materially modified in @@SCOPE@@ during the
last seven complete days. Query Activity Log and Azure Resource Graph. Correlate each event with
caller identity, operation, deployment/correlation ID, resource type, resource group, subscription,
tags, and current existence. Deduplicate child-operation noise into one logical change where possible.

Return separate Added, Removed, Moved, and Modified tables; summarize counts by subscription,
resource type, caller, and deployment; flag changes outside @@APPROVED_CHANGE_WINDOW@@ or without
@@CHANGE_TAG@@; and disclose events that may be unavailable because of retention. Read-only.
```

**Scheduled-task prompt**

```text
Produce the weekly resource lifecycle digest for @@SCOPE@@. Summarize logical adds, removals, moves,
and material updates; attribute callers and deployment IDs; flag unapproved changes; and include
source, UTC window, and coverage gaps. Do not revert or delete anything.
```

**Acceptance:** handles deleted resources from Activity Log even though Resource Graph cannot list them.

## 7. Show everything changed in the last 24 hours

**Interactive prompt**

```text
Build a unified UTC change timeline for @@SCOPE@@ covering the last 24 hours. Include Azure resource
writes/deletes/actions, deployments and revision changes, NSG/route/firewall changes, RBAC and policy
changes, diagnostic/alert changes, Key Vault metadata changes, and relevant code or pipeline releases.

Group noisy child operations by correlation or deployment ID. For every logical change show time,
actor, channel, target, before/after when available, result, and linked incident or deployment. Rank
changes by likely operational impact, identify suspicious or failed changes, and state what data
sources were not available. Do not label a change causal unless timing and independent telemetry
support it. Read-only.
```

**Scheduled-task prompt**

```text
Create the daily 24-hour change digest for @@SCOPE@@. Deduplicate related operations, highlight
failed/high-risk/out-of-window changes, correlate active incidents, and publish a concise timeline
with source coverage and gaps. Read-only; do not revert changes.
```

**Acceptance:** produces logical changes rather than a raw, repetitive Activity Log dump.

## 8. Entra authentication troubleshooting

**Interactive prompt**

```text
Investigate authentication failures for @@APPLICATION_OR_PRINCIPAL@@ from @@START_UTC@@ to
@@END_UTC@@. Use the scoped Entra sign-in and audit logs available in Log Analytics. Correlate user,
service-principal, and managed-identity sign-ins as applicable with application ID, resource, tenant,
client type, location summary, Conditional Access result, authentication requirement, result/error
code, credential or federation configuration changes, app-role/API permission changes, and Azure RBAC.

Aggregate and redact PII; do not print tokens, full IP addresses, user-entered text, or credential
material. Distinguish authentication, token acquisition, Conditional Access, consent/API permission,
federation, and Azure authorization failures. Return failure trend, affected scope, top error codes,
UTC timeline, likely cause with confidence, and safe remediation steps. Do not disable users, reset
credentials, modify policies, grant consent, or change role assignments.
```

**Acceptance:** separates a successful token acquisition followed by RBAC denial from a true sign-in failure.

## 9. Capacity exhaustion prediction

**Interactive prompt**

```text
Forecast capacity exhaustion for @@SCOPE@@ over the next @@FORECAST_DAYS@@ days. Use at least
@@HISTORY_DAYS@@ days of hourly data for workload demand and relevant limits: VM/VMSS CPU and memory,
disk capacity/IOPS/throughput, network limits, Container Apps or AKS replica/node capacity, database
storage/connections/workers, Log Analytics ingestion cap, and regional/subscription quota.

Clean missing periods explicitly and model trend plus weekly seasonality where the data supports it.
For each constrained dimension report current usage, hard or practical limit, headroom, growth rate,
forecast exhaustion date or “not within horizon,” confidence interval, data quality, and recommended
lead time/action. Label seeded data and simple linear estimates honestly. Never invent a forecast from
insufficient history. Read-only; do not scale resources or request quota.
```

**Scheduled-task prompt**

```text
Run the weekly @@FORECAST_DAYS@@-day capacity forecast for @@SCOPE@@. Rank resources expected to
cross warning or critical headroom, include forecast date/range and confidence, identify quota versus
workload constraints, and recommend lead-time-aware actions. Mark insufficient data as inconclusive.
Read-only.
```

**Acceptance:** includes uncertainty and does not treat a short CPU spike as a capacity trend.

## 10. Failed deployment investigation

**Interactive prompt**

```text
Investigate the failed or unhealthy deployment @@DEPLOYMENT_ID_OR_RESOURCE@@ in @@SCOPE@@ during
@@START_UTC@@ to @@END_UTC@@. Correlate ARM deployment operations and errors, Activity Log,
pipeline/run metadata, image or artifact identity, configuration and secret references, policy/RBAC
denials, quota, platform events, revision health, application requests/exceptions, and the last known
good deployment.

Build a deployment timeline from commit/artifact through control-plane operations to runtime health.
Identify the first failing stage and distinguish deployment failure from successful deployment with
a runtime regression. Check for drift or an out-of-band change. Recommend rollback, roll-forward, or
configuration correction with evidence and risk, but do not redeploy, shift traffic, or roll back
without approval. Verify against the original health signal.
```

**Acceptance:** correlates the first bad revision or failed ARM operation and preserves the last known good state.

## 11. Azure cost anomaly detection

**Interactive prompt**

```text
Analyze cost anomalies in @@SCOPE@@ for @@CURRENT_WINDOW@@ against @@BASELINE_WINDOW@@. Prefer actual
and amortized Cost Management data and state which measure is used. Group by subscription, resource
group, service, resource ID, meter/category, region, and tag where available. Compare absolute and
percentage deltas, account for new resources and known seasonality, and correlate anomalous drivers
with Activity Log, SKU/scale changes, deployments, reservations/savings plans, and utilization.

Rank anomalies by financial impact. For each, report current cost, expected/baseline cost, delta,
driver, operational explanation, confidence, and concrete optimization. Separate genuine anomalies
from delayed charges or allocation changes. If billing data is unavailable, use a clearly labeled
inventory estimate and do not present it as billed cost. Read-only; never resize, stop, or delete.
```

**Scheduled-task prompt**

```text
Run the daily cost anomaly review for @@SCOPE@@, comparing the latest complete cost window with the
approved baseline. Rank material anomalies by absolute impact, correlate resource changes, and post
the top drivers, confidence, projected monthly impact, and recommended owner action. State data
freshness and source. Read-only.
```

**Acceptance:** identifies the seeded scale-up or cost record and states Cost Management data latency.

## 12. Security incident investigation

**Interactive prompt**

```text
Investigate security incident @@INCIDENT_ID_OR_SYMPTOM@@ in @@SCOPE@@ from @@START_UTC@@ to
@@END_UTC@@. Correlate Defender for Cloud or Sentinel findings when connected with Entra sign-ins,
Activity Log, resource configuration, NSG/firewall/flow logs, Key Vault audit metadata, VM/app logs,
and deployment history. Build an immutable UTC timeline and identify affected identities, assets,
entry point, actions, persistence indicators, and blast radius.

Classify every statement as observed, inferred, or unknown. Preserve evidence references and redact
secrets and PII. Recommend immediate containment, eradication, recovery, and prevention in priority
order, including business impact and risk. Do not block identities, rotate credentials, isolate
networks, delete resources, or alter evidence without explicit incident-commander approval. Escalate
when compromise cannot be ruled out.
```

**Acceptance:** attributes the lab NSG exposure/change and scopes impact without claiming compromise solely from exposure.

## 13. Multi-subscription operational health overview

**Interactive prompt**

```text
Create an operational health overview across subscriptions @@SUBSCRIPTION_IDS@@ for the period
@@START_UTC@@ to @@END_UTC@@. For each subscription summarize Azure Service Health and Resource
Health, active Monitor incidents, critical alerts, availability/SLO breaches, capacity/quota risk,
security recommendations, failed deployments, material changes, and cost anomalies using only the
authorized sources.

Normalize severity and avoid double-counting shared incidents. Return an executive estate scorecard,
per-subscription findings, top cross-estate risks, ownership/escalation, and recommended next actions.
Show inaccessible subscriptions and missing permissions as coverage gaps, not healthy status. Keep
tenant boundaries explicit. Read-only; no cross-subscription remediation.
```

**Scheduled-task prompt**

```text
Generate the daily multi-subscription health digest for @@SUBSCRIPTION_IDS@@. Produce a normalized
scorecard, active incidents and SLO breaches, capacity/security/cost/change risks, and the top owner
actions. Explicitly list inaccessible scopes and stale or missing sources. Read-only.
```

**Acceptance:** reports partial visibility honestly and does not aggregate inaccessible scopes as green.

## Facilitator follow-up prompts

Use these after any investigation to test reasoning quality:

```text
Show only the evidence that directly supports your leading conclusion, and list evidence that would
falsify it.
```

```text
What did you query, what could you not query, and how would each missing source change confidence?
```

```text
Separate immediate mitigation, durable engineering fix, detection improvement, and process action.
Assign an owner role and target urgency to each; do not execute them.
```

```text
Reformat the result for an incident commander: five-sentence summary, UTC timeline, impact, current
status, next decision, and approval required.
```
