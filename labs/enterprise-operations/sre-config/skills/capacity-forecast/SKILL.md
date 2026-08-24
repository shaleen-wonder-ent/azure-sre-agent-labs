---
name: capacity-forecast
version: 1.0.0
description: Use for capacity exhaustion prediction. Check data quality, model trend and weekly seasonality where supported, forecast when a dimension crosses warning and critical headroom, and distinguish resource limits from subscription quota.
tools:
  - SearchMemory
  - QueryLogAnalyticsByWorkspaceId
  - RunAzCliReadCommands
  - GetAzCliHelp
---

# Capacity Exhaustion Forecast

Estimate when a workload dimension or an Azure quota will cross warning and critical headroom, with
data-quality checks, uncertainty, and enough lead time to act.

## Evidence sources

- Azure Monitor metrics and `InsightsMetrics`/`Perf` for CPU, memory, disk, and network.
- Database storage, connections, and worker metrics; Container Apps or AKS replica/node capacity.
- Log Analytics ingestion against the daily cap.
- Subscription and regional quota/usage via `az` for the resource provider.
- When the scope has no usable metric history in the workspace, use the `capacity-forecast-fixture.json`
  time series provided with this skill. Its samples carry explicit limits and warning/critical levels.

## Method

1. Restate scope, dimensions, history length, and forecast horizon in UTC.
2. Assess data quality first: sample count, gaps, outliers, and whether the range supports trend and
   weekly seasonality. Do not fit a model the data cannot support.
3. For each dimension, compute current usage, the hard limit, current headroom, and the growth rate.
4. Model trend, and add weekly seasonality only where the history shows it. Forecast the crossing of
   the warning and critical levels, and of the hard limit.
5. Report a forecast range or confidence interval, not a single deterministic date.
6. Separate a resource limit (for example provisioned storage or connection ceiling) from a
   subscription or regional quota. Name the binding constraint.
7. Recommend the least disruptive lead-time-aware action: cleanup, right-size, partition, scale, or a
   quota request. Do not scale or request quota yourself.

## Rules

- Insufficient or gap-heavy history returns `Inconclusive` with the reason. Never invent a date.
- A short spike is not a sustained trend. Exclude transient outliers from the growth model and say so.
- Forecast the seasonal peak, not the average, when the limit is a peak constraint.
- State assumptions: linear versus compounding growth, and the seasonality period used.

## Required report

Return scope and UTC window, data-quality summary (samples, gaps, seasonality), a per-dimension table
of current usage, limit, headroom, growth rate, forecast date range, and confidence, the ranked
dimension closest to exhaustion, the binding constraint (resource versus quota), lead-time-aware
recommendations with owner and approval requirement, and data gaps.
