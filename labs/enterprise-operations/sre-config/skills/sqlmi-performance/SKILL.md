---
name: sqlmi-performance
version: 1.0.0
description: Use for evidence-first Azure SQL Managed Instance performance investigations that correlate Azure Monitor with operator-supplied read-only Query Store and DMV evidence.
tools:
  - SearchMemory
  - QueryLogAnalyticsByWorkspaceId
  - RunAzCliReadCommands
  - GetAzCliHelp
---

# SQL MI Performance

Investigate the private `sre_demo` database without exposing credentials or performing a database write.

## Evidence boundary

- Query Azure Monitor metrics, alerts, Resource Health, Activity Log, and Log Analytics directly with read-only tools.
- The SQL MI data endpoint is private. Do not attempt guest Run Command, SQL login, session termination, DDL, configuration, indexing, or scaling through agent tools.
- Query Store and DMV evidence must come from output supplied by an operator running:
  `pwsh ./scripts/Invoke-SqlMiDemo.ps1 -Action Diagnose`.
- This lab uses delegated operator mode because tenant-level directory-read permission cannot be
  granted to the SQL MI identity. The script transports a fresh short-lived Azure SQL token as a
  protected Run Command parameter and does not persist it. Do not describe this fallback as a
  production identity design or as least privilege.
- Treat missing operator output as a coverage gap. Never infer blocking, waits, or query-plan behavior from application latency alone.
- Do not request, repeat, store, or expose SQL credentials or unredacted statement text.

## Workflow

1. Confirm the SQL MI resource ID, `sre_demo` database, and explicit UTC incident window.
2. Query CPU, data IO, log IO, storage, sessions/workers, availability, alerts, Resource Health, and recent control-plane changes.
3. Parse supplied diagnostic output for active requests, blocking session IDs, wait types/resources, and Query Store aggregates.
4. Build one UTC timeline and separate observed Azure evidence, observed SQL evidence, inference, and unknowns.
5. Rank blocking, query plan/index, compute, IO, storage, connection/session, and platform hypotheses by impact and confidence.
6. Recommend the least disruptive action with expected benefit, risk, rollback, and verification. Do not perform it.

## Demo fault

The seeded fault is a bounded transaction lock on `dbo.Inventory`. An operator may start it only with:

`pwsh ./scripts/Invoke-SqlMiDemo.ps1 -Action Fault -DurationSeconds 600 -ApproveWrite`

It returns after the lock is active and a background supervisor rolls it back after at most ten
minutes. Emergency cleanup requires explicit approval:

`pwsh ./scripts/Invoke-SqlMiDemo.ps1 -Action Reset -ApproveWrite`

## Required report

Return the scope and UTC window, source coverage, evidence timeline, blocking/wait findings, Query Store findings, Azure resource findings, ranked hypotheses, recommendation, approval requirement, reset/rollback, verification, and evidence gaps.
