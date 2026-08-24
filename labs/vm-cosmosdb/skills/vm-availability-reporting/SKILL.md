# VM Availability Reporting

Use this skill to produce a read-only VM availability report for a requested UTC window.

## Required Behavior

1. State the requested window, sampling interval, SLO, formula, and source coverage before reporting availability.
2. Query real Azure evidence when available:
   - `VmAvailabilityMetric`
   - Resource Health events
   - `Heartbeat`
   - VM start, restart, power-off, and deallocation operations in Activity Log
3. Classify every minute as available, unavailable, unknown, or excluded using `slo-and-availability-rules.md`.
4. Never count unknown minutes as available.
5. Never claim 30 days of observed availability when the resource or telemetry is younger than 30 complete days.
6. Use `vm-availability-30d-fixture.json` only when the user asks for the workshop fixture or when real coverage is insufficient and the user accepts a synthetic demonstration.
7. Keep observed Azure results and prepared fixture results in separate sections. Display the fixture disclaimer prominently.
8. Perform no remediation or write operation.

## Verified Demo Snapshot

For the window ending `2026-08-24T00:00:00Z`, the following observed context was independently verified on `2026-08-24`. Use it when live metric commands are unavailable, label it as a timestamped snapshot, and do not extrapolate it:

- VM creation: `2026-08-21T06:45:29Z`
- `VmAvailabilityMetric`: 820 samples from `2026-08-21T06:46:00Z` through `2026-08-24T06:39:00Z`
- Metric classifications: 817 available, 2 partial, and 1 unavailable
- `Heartbeat`: zero records in the 30-day query
- Log Analytics workspace and Azure Monitor Agent exist, but no Data Collection Rule association sends heartbeat data

The metric extends beyond the requested midnight boundary, so these counts describe source coverage rather than the requested observed availability result. The VM age alone proves that the complete 30-day window cannot be observed.

## Prepared Workshop Fixture

The following data is embedded so the runtime does not depend on files being mounted in the skill sandbox. The canonical copy is `vm-availability-30d-fixture.json` in indexed memory.

- Classification: `synthetic_prepared_fixture`
- Disclaimer: **Synthetic 30-day fixture; not measured production availability.**
- Resource: `vm-sap-app-01` in `rg-srelab-vmcosmos`
- Window: `2026-07-25T00:00:00Z` through `2026-08-24T00:00:00Z` (end exclusive)
- Sampling interval: 1 minute
- Total: 43,200 minutes
- Available: 42,745 minutes
- Unavailable: 125 minutes
- Unknown: 90 minutes
- Excluded: 240 minutes
- SLO: 99.9 percent

Synthetic outage timeline:

| Start UTC | Minutes | Cause | Evidence |
|---|---:|---|---|
| 2026-07-29T10:15:00Z | 20 | Application process stopped responding | Synthetic application health event |
| 2026-08-03T03:00:00Z | 45 | Azure host interruption | Synthetic Resource Health event |
| 2026-08-12T14:40:00Z | 60 | Network route misconfiguration | Synthetic Activity Log correlation |

Unknown interval: 90 minutes beginning `2026-08-07T05:00:00Z` due to unavailable telemetry.

Planned exclusion: 240 minutes beginning `2026-08-16T01:00:00Z` for approved operating-system maintenance.

For this fixture, calculate:

```text
eligible_minutes = available_minutes + unavailable_minutes
availability_percent = 100 * available_minutes / eligible_minutes
coverage_percent = 100 * eligible_minutes / (total_minutes - excluded_minutes)
```

The independently validated results at four decimal places are `99.7084%` availability and `99.7905%` coverage. Recalculate them, compare with these check values, and report a mismatch rather than substituting a different result.

## Fixture Validation

Before using the prepared fixture:

- Verify that available, unavailable, unknown, and excluded minutes sum to total window minutes.
- Recalculate availability and coverage from the methodology rather than trusting stored expected values.
- Verify that the fixture window matches the requested demo window.
- Report any mismatch instead of silently correcting the fixture.

## Output

Produce:

1. **Methodology**: formula, sampling interval, SLO, and treatment of unknown and excluded minutes.
2. **Observed Azure evidence**: source, first sample, last sample, sample count, and retention/onboarding gaps.
3. **Synthetic 30-day demonstration** when requested: conspicuous disclaimer and the calculated result.
4. **Per-VM table**: total, available, unavailable, unknown, excluded, availability, coverage, longest outage, outage count, and SLO result.
5. **Outage timeline**: start, duration, cause, and evidence type.
6. **Data-quality findings**: missing heartbeat, incomplete retention, conflicting signals, and assumptions.

Do not blend observed and synthetic percentages into a fleet average.
