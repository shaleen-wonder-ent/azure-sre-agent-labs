---
name: security-investigation
version: 1.0.0
description: Use for Azure security incident investigation. Build an evidence-preserving UTC timeline, attribute changes, scope blast radius, and distinguish exposure from compromise without overstating impact.
tools:
  - SearchMemory
  - QueryLogAnalyticsByWorkspaceId
  - RunAzCliReadCommands
  - GetAzCliHelp
---

# Security Incident Investigation

Investigate a suspected security incident, attribute the change, and scope impact precisely.

## Evidence sources

- Activity Log: who made the change, when, from where, and the operation and result.
- Current resource configuration: NSG rules and associations, public IP exposure, firewall state.
- Network telemetry where available: NSG flow logs, connection monitor, VM/app logs.
- Entra sign-in and audit logs and Key Vault audit metadata when identity or secrets are in scope.
- ARM deployment history for correlated control-plane changes.
- Defender for Cloud or Sentinel findings only when connected.

## Method

1. Restate the incident, scope, and explicit UTC window.
2. Build one immutable UTC timeline. Preserve evidence references (resource IDs, correlation IDs,
   operation names, caller). Do not alter any resource.
3. Attribute each change to a caller identity, time, source IP prefix, and operation from the Activity Log.
4. Identify the entry point and the affected assets. For an NSG exposure, determine the rule, the
   port/protocol/source, and whether the NSG is associated with a subnet or NIC and whether any target
   has a public IP.
5. Scope blast radius from association and reachability, not from the rule alone.
6. Look for evidence of actual access or actions: connections, sign-ins, data operations, new
   principals, or persistence indicators.
7. Recommend containment, eradication, recovery, and prevention in priority order with business impact.

## Discipline

- Label every statement **observed**, **inferred**, or **unknown**.
- Say **exposed** when configuration allows access. Say **compromised** only when evidence proves access
  or malicious action occurred. Never infer compromise from exposure alone.
- Redact secrets, tokens, credentials, and PII; truncate IP addresses to a prefix.
- All containment (NSG change, identity block, credential rotation, isolation, deletion) requires
  incident-commander approval. Never alter evidence.
- Escalate when compromise cannot be ruled out.

## Required report

Return the incident scope and UTC window, source coverage, the evidence timeline, attribution
(who/when/where), affected assets and entry point, blast radius with reachability, an explicit
exposure-versus-compromise determination, ranked containment/eradication/recovery/prevention actions
with approval requirements, verification steps, and evidence gaps.
