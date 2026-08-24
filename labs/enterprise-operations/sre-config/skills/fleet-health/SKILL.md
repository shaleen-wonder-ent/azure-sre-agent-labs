---
name: fleet-health
version: 1.0.0
description: Use for multi-scope operational health overviews across subscriptions or resource-group environments. Run a per-scope coverage check first, normalize severity, avoid double-counting, and report inaccessible scopes as blind spots rather than healthy.
tools:
  - SearchMemory
  - QueryLogAnalyticsByWorkspaceId
  - RunAzCliReadCommands
  - GetAzCliHelp
---

# Fleet Health Overview

Produce a consolidated operational health scorecard across several scopes. A scope is a subscription
or a resource-group environment. Never present an unreachable scope as healthy.

## Coverage check first

1. For each scope, verify access before assessing health. Try to list the scope
   (`az account show`, `az group show`, or `az resource list`). Record accessible, partial, or
   inaccessible with the specific error (authorization, not found, throttled).
2. A scope you cannot read is a **blind spot**, reported as `Unknown`. Do not roll it into a healthy
   or green status. State the missing permission or resource explicitly.

## Per-scope evidence

For each accessible scope, gather only from authorized sources:

- Resource Health and provisioning state of key resources.
- Active Azure Monitor alerts and incidents.
- Availability or SLO breaches where telemetry exists.
- Capacity and quota risk.
- Failed deployments in the window.
- Material configuration, RBAC, or policy changes.
- Security posture signals (open exposure, risky rules) and cost anomalies when in scope.

## Normalization and aggregation

- Map every finding to one severity scale: Critical, High, Medium, Low, Info.
- Deduplicate shared incidents across scopes by correlation or deployment ID; count each logical issue
  once.
- Compute a per-scope status from its worst unresolved finding, and an estate status that never reports
  green while any scope is Unknown or Critical.
- Keep tenant boundaries explicit. Do not compare across tenants.

## Rules

- Read-only. No cross-scope remediation, no writes.
- Label findings observed, inferred, or unknown.
- An empty query or permission failure is `Unknown` or `Inconclusive`, never `Healthy`.
- Redact secrets, credentials, and PII; truncate IP addresses.

## Required report

Return an executive estate scorecard (per-scope status plus one estate status), a coverage table
(accessible/partial/inaccessible with reasons), per-scope findings ranked by normalized severity, the
top cross-estate risks with owners and escalation, recommended read-only next actions, and an explicit
blind-spot list of inaccessible scopes and stale or missing sources.
