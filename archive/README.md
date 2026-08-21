# Archive — non-Azure-native content (parked, not deployed)

This folder holds labs and recipes that depend on **third-party** or **on-premises**
systems. They are intentionally **excluded** from the Azure-centric lab IP and from the
master deployment script. Nothing here is deleted — it is preserved for the follow-up
conversation about third-party and hybrid scenarios.

> **Why parked:** Keeping live on-prem + third-party dependencies (F5, Dynatrace,
> ServiceNow, PagerDuty, Terraform Cloud, AWS, Arc/ExpressRoute) in an automated,
> "deploy-the-whole-lab" IP is operationally heavy and hard to reproduce for a customer.
> These scenarios are discussed manually instead.

## Archived labs

| Lab | Third-party / on-prem dependency |
|-----|----------------------------------|
| `labs/deployment-guard` | Dynatrace (telemetry), Dynatrace MCP gateway |
| `labs/f5-bigip-observability` | F5 BIG-IP VE (marketplace), F5 Telemetry Streaming |
| `labs/terraform-drift-detection` | Terraform Cloud webhook, Microsoft Teams notification |

## Archived recipes (`sreagent-templates` toolkit)

| Recipe | Third-party dependency |
|--------|------------------------|
| `recipes/dynatrace-mcp` | Dynatrace |
| `recipes/dynatrace-servicenow` | Dynatrace + ServiceNow |
| `recipes/law-dynatrace-github-httptrigger-prvalidation` | Dynatrace |
| `recipes/pagerduty-law-vmcosmos` | PagerDuty |
| `recipes/azuretoaws-sre-agent` | AWS |

## Known follow-ups when un-archiving

- The template test harness under `sreagent-templates/tests/` still references the
  archived recipe names (e.g. `test-dry-run-dynatrace.sh`, `test-e2e-3p.sh`). Those
  dev-time tests are not part of the customer lab deploy path; re-wire them if the
  recipes are restored.
- `.github/workflows/validate-templates.yml` enumerates recipe names for dry-run tests.

To restore an item, move it back under `labs/` or `sreagent-templates/recipes/` and
re-add its references to the top-level docs and master script.
