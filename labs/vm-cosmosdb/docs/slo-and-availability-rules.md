# VM Availability Methodology

## Scope

- Target: `vm-sap-app-01` in `rg-srelab-vmcosmos`
- Sampling interval: one minute
- Default SLO: 99.9 percent
- Report window: 30 complete UTC days ending at the requested UTC midnight

## Classification

Every minute in the window must be classified exactly once:

- **Available**: the Azure `VmAvailabilityMetric` value is `1`.
- **Unavailable**: the metric value is `0`, or Resource Health confirms an unplanned outage.
- **Unknown**: no trustworthy availability signal exists and no planned exclusion applies.
- **Excluded**: an approved maintenance or shutdown interval is documented before the event.
- Metric values between `0` and `1` are unavailable unless stronger Resource Health evidence resolves the minute.

Unknown minutes must never be counted as available. A scheduled shutdown is excluded only when its interval is explicitly documented; an auto-shutdown configuration without a corresponding planned start time does not make an open-ended telemetry gap an exclusion.

## Formula

The report uses service-observed availability:

```text
eligible_minutes = available_minutes + unavailable_minutes
availability_percent = 100 * available_minutes / eligible_minutes
coverage_percent = 100 * eligible_minutes / (total_window_minutes - excluded_minutes)
```

If `eligible_minutes` is zero, availability is unknown. Always report unknown and excluded minutes beside availability. A report may claim full 30-day coverage only when every minute is classified and the source covers the complete window.

## Source Precedence

1. Azure `VmAvailabilityMetric`
2. Azure Resource Health events
3. Corroborating `Heartbeat` records
4. VM power operations from Azure Activity Log
5. Explicitly labeled prepared fixture data

Never merge prepared fixture minutes into a real Azure availability percentage. Present observed and synthetic results as separate sections.
