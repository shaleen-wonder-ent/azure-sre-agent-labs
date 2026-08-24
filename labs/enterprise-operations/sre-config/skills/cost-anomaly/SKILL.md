---
name: cost-anomaly
version: 1.0.0
description: Use for Azure cost anomaly detection. Compare a current window to a baseline, rank drivers by financial impact, correlate cost changes with resource and SKU changes, and separate genuine anomalies from delayed charges or new-resource cost.
tools:
  - SearchMemory
  - QueryLogAnalyticsByWorkspaceId
  - RunAzCliReadCommands
  - GetAzCliHelp
---

# Cost Anomaly Detection

Identify material spend changes, explain their operational drivers, and recommend read-only savings.

## Evidence sources

- Prefer live Azure Cost Management via CLI (for example an `az rest` POST to the
  `Microsoft.CostManagement/query` API) for actual or amortized cost. State which measure is used.
- If the Cost Management API is unavailable, throttled, or access is denied, use the
  `cost-anomaly-fixture.json` dataset provided with this skill. Treat it as an estimate, not a billed
  invoice, and say so.
- Correlate drivers with Activity Log and ARM deployment history for SKU, scale, and new-resource
  events. Use Azure Monitor utilization to judge whether spend matches usage.

## Method

1. Restate scope, the current window, the baseline window, the cost measure, and data freshness.
2. Aggregate cost by service and, where available, by resource group, resource, meter, region, and tag.
3. Compare current versus baseline as both absolute and percentage deltas.
4. Rank anomalies by absolute financial impact, not percentage alone.
5. For each material anomaly, identify the driver and correlate it with a specific resource or
   deployment change. A brand-new resource is expected cost, not necessarily an anomaly - label it as
   a new-resource cost with its own projected monthly impact.
6. Separate genuine anomalies from billing latency, one-time charges, or allocation/tag changes.
7. Recommend concrete, read-only optimizations with projected monthly savings. Never resize, stop,
   deallocate, or delete.

## Rules

- Always state the source (actual, amortized, or estimated) and the data-freshness lag.
- Never present an estimate or inventory-based figure as a billed amount.
- Project monthly impact from a representative daily rate, and note if the current day is partial.
- Distinguish a resource limit or quota constraint from a spend driver; this scenario is about spend.

## Required report

Return scope and windows, cost measure and freshness, a ranked driver table (current, baseline, delta
absolute and percent, driver, correlated change, confidence), the separation of genuine anomaly versus
new-resource or latency, projected monthly impact, read-only optimization recommendations with owner,
and data gaps.
