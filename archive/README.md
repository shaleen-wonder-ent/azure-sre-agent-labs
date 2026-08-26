# Archive — parked content (not part of the core deploy path)

This folder holds material intentionally kept out of the root so the top-level
[README](../README.md) stays focused on **deploy → warm up → fix**. Nothing here is deleted.

## What's parked here

| Item | What it is | Why parked |
|------|-----------|------------|
| [reference/](reference/) | Deep-dive docs: use-case catalog, cost evidence, product guide, and the full demo runbook. | Essentials are folded into the root README; these remain as detailed reference. |
| [resources.md](resources.md) | Product links, videos, blogs, and community repos (the former "community hub"). | Kept off the front page to reduce clutter. |
| [sreagent-templates/](sreagent-templates/) | Generic agent-scaffolding toolkit (Bicep/Terraform recipes, CLI). | A separate toolkit, not required to deploy or run the labs. |
| [sreagent-templates-ci/](sreagent-templates-ci/) | The `validate-templates` GitHub workflow and the recipe-request issue template. | Moved out of `.github/` so the archived toolkit's CI no longer runs. |
| `labs/` | Third-party / on-prem labs (see below). | External dependencies are hard to reproduce automatically. |

## Third-party / on-premises content

They depend on **third-party** or **on-premises** systems and are excluded from the
Azure-centric lab IP and the master deployment script.

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

Now located at [sreagent-templates/recipes/](sreagent-templates/recipes/).

| Recipe | Third-party dependency |
|--------|------------------------|
| `recipes/dynatrace-mcp` | Dynatrace |
| `recipes/dynatrace-servicenow` | Dynatrace + ServiceNow |
| `recipes/law-dynatrace-github-httptrigger-prvalidation` | Dynatrace |
| `recipes/pagerduty-law-vmcosmos` | PagerDuty |
| `recipes/azuretoaws-sre-agent` | AWS |

## Known follow-ups when un-archiving

- The `sreagent-templates` toolkit and its CI now live under this `archive/` folder. To make it
  active again, move `sreagent-templates/` back to the repo root and move
  `sreagent-templates-ci/validate-templates.yml` back to `.github/workflows/` (and the recipe-request
  issue template back to `.github/ISSUE_TEMPLATE/`).
- The template test harness under `sreagent-templates/tests/` references archived recipe names
  (e.g. `test-dry-run-dynatrace.sh`, `test-e2e-3p.sh`); re-wire them if the recipes are restored.

To restore an item, move it back under `labs/` or `sreagent-templates/recipes/` and
re-add its references to the top-level docs and master script.
