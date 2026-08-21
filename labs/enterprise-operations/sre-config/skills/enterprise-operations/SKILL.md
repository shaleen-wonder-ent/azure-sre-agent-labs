---
name: enterprise-operations
version: 1.0.0
description: Use for evidence-first Azure operational investigations and reports covering application outages, network connectivity, VM incidents and availability, SQL MI performance, resource lifecycle and changes, Entra authentication, capacity, deployments, cost, security, and multi-subscription health.
tools:
  - SearchMemory
  - QueryLogAnalyticsByWorkspaceId
  - RunAzCliReadCommands
  - GetAzCliHelp
---

# Enterprise Operations

Use this skill for the 13 scenarios in `scenario-prompts.md`. Select the smallest relevant workflow and remain read-only unless the user explicitly requests a change and the global approval hook accepts it.

## Evidence contract

1. Restate the scope and use an explicit UTC start and end time.
2. Name every source queried. Treat an empty result as no evidence in that source and window, not proof that nothing happened.
3. Build a UTC timeline before claiming causality.
4. Separate observed facts, inference, and unknowns. Rank hypotheses and give confidence.
5. Correlate independent control-plane, data-plane, guest, identity, network, cost, or security evidence when applicable.
6. Redact secrets, tokens, full IP addresses, sensitive query text, and personally identifiable information.
7. Never restart, resize, redeploy, roll back, alter routing or security policy, modify identity, kill database sessions, or delete resources without explicit approval.
8. Verify any approved mitigation against the original user-visible symptom and show before/after evidence.

## Scenario routing

- Application outage: requests, dependencies, exceptions, metrics, alerts, Resource Health, Activity Log, deployments, and network path.
- Connectivity: DNS, effective NSG and routes, peering, Connection Monitor, Application Gateway backend health, and destination listener.
- VM incident: power and Resource Health, heartbeat, CPU, memory, disk, network, extensions, guest logs, and platform maintenance.
- SQL MI: Query Store and safe read-only DMVs plus CPU, IO, storage, connections, workers, waits, blocking, and deployment changes.
- VM availability: define the formula; report available, unavailable, unknown, and excluded time separately.
- Resource lifecycle and daily changes: correlate Activity Log and Resource Graph and deduplicate by correlation or deployment ID.
- Entra authentication: distinguish sign-in/token failures, Conditional Access, consent/API permissions, federation, and downstream Azure RBAC denial.
- Capacity: use sufficient history, model trend and seasonality only when supported, and report uncertainty and quota headroom.
- Failed deployment: find the first failing stage from artifact through ARM and runtime health and preserve last-known-good evidence.
- Cost anomaly: state actual versus amortized source and freshness; correlate deltas with resource and SKU changes.
- Security: preserve evidence, label observed/inferred/unknown, scope blast radius, and require incident-commander approval for containment.
- Multi-subscription health: normalize severity, avoid double counting, and report inaccessible scopes as unknown rather than healthy.

## Required report

Return:

- Scope and UTC window
- Executive summary
- Source and coverage table
- Evidence timeline
- Findings ranked by severity or impact
- Leading conclusion, alternatives, and confidence
- Blast radius
- Recommended next actions with owner, urgency, risk, and approval requirement
- Verification criteria
- Missing telemetry and permissions
