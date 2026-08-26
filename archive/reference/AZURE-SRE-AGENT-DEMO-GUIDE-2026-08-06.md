# Azure SRE Agent - Demo Guide

**Demo date:** August 6, 2026  
**Audience:** SRE, platform engineering, cloud operations, application owners, and leadership  
**Product status:** Generally Available (GA)

> **One-sentence summary:** Azure SRE Agent is an AI-powered operations teammate that connects telemetry, Azure resources, incident systems, source code, and operational knowledge to investigate issues, explain root cause, recommend or execute mitigations, and automate recurring reliability work within configured permissions and guardrails.

> **Companion:** For the Azure-native use-case catalog (13 scenarios mapped to labs and Azure data sources), see [AZURE-SRE-AGENT-USE-CASES.md](AZURE-SRE-AGENT-USE-CASES.md). This guide and that catalog are **Azure-centric**; third-party and on-premises scenarios are parked under [`archive/`](../) and discussed separately.

> **Deploy & record fast:** Provision the labs with [`Deploy-SreAgentLabs.ps1`](../../Deploy-SreAgentLabs.ps1)
> (interactive scenario picker, cost/readiness warnings, and GitHub prompts for the connected labs).
> Then use the one-command warm-up scripts in [`demo/`](../../demo/) — one per use case — to seed each
> incident and print the exact prompt. The full recording script is in
> [SRE-AGENT-DEMO-RUNBOOK.md](SRE-AGENT-DEMO-RUNBOOK.md).

## Executive takeaway

Azure SRE Agent is not just a chatbot over Azure Monitor. It is an agentic operations service that can reason across signals, call tools, run investigations, retain operational context, route work to specialists, and take approved actions.

The most important deployment principle is:

> **The agent's deployment location is not the same as its operational scope.**

An agent is created as an Azure resource in one subscription, resource group, and region. Its operational reach is determined by the Azure RBAC granted to its managed identity and by the external systems connected to it.

A single agent can cover multiple workloads, resource groups, and subscriptions. That does not mean one agent should automatically cover an entire enterprise. Start with one agent for a related application or platform boundary, then split agents when ownership, permissions, data residency, risk, or operational context differ.

---

## 1. What is Azure SRE Agent?

Azure SRE Agent helps operations teams reduce incident-response time and repetitive operational toil. It works alongside engineers by combining:

- Azure service and SRE domain knowledge
- Natural-language interaction
- Access to live resource configuration, metrics, logs, alerts, and code
- Tool use through Azure capabilities, connectors, Python, skills, and MCP servers
- Persistent memory and knowledge from previous investigations
- Automation through incidents, schedules, and event-driven triggers
- Governance through Azure RBAC, tool permissions, hooks, audit telemetry, and approval modes

It is designed to answer questions such as:

- What changed before this outage?
- Which services and customers are affected?
- What is the most likely root cause, and what evidence supports it?
- Which mitigation is safest right now?
- Can this known recovery action be performed after approval?
- Are reliability, compliance, cost, or capacity risks emerging before an incident occurs?

### What it is not

- It is not a replacement for monitoring, alerting, or observability platforms.
- It is not automatically an unrestricted administrator for Azure.
- It is not guaranteed to be correct; AI conclusions and proposed changes still require appropriate validation and guardrails.
- It is not a substitute for service ownership, SLOs, tested runbooks, or sound incident management.

---

## 2. Core capabilities

| Capability | What it does | Example |
|---|---|---|
| Incident investigation | Correlates alerts, logs, metrics, resource state, deployments, and code | Relate an error-rate spike to a recent commit and configuration change |
| Root-cause analysis | Forms and tests hypotheses, then presents evidence and affected scope | Identify memory pressure caused by a bad deployment |
| Mitigation | Recommends or performs authorized actions | Restart a pod, scale a resource, or roll back a deployment |
| Interactive operations | Answers grounded questions about the environment | "What changed in production in the last hour?" |
| Scheduled operations | Runs recurring natural-language tasks | Daily health check, weekly cost review, certificate-expiry scan |
| Incident automation | Routes matching incidents to a suitable custom agent | Send P1 database incidents to a database specialist |
| Deep context | Uses source code, architecture, runbooks, postmortems, and persistent memory | Apply a team's known recovery procedure and escalation policy |
| Extensibility | Adds skills, custom agents, Python tools, hooks, and MCP tools | Add a Kusto/Log Analytics query tool, a Python calculation, or a custom MCP tool for an internal API |
| Collaboration | Publishes findings to existing systems | Update the Azure Monitor incident and open a GitHub issue for the team |
| Closed-loop engineering | Connects operational findings to development workflows | Open a contextual GitHub issue for a durable code fix |

### Azure services it can work with

Through Azure Resource Manager, Azure Resource Graph, Azure CLI, Azure Monitor, and service-specific tools, the agent can investigate a broad range of services, including:

- Compute: VMs, App Service, Container Apps, AKS, and Functions
- Data: Azure SQL, Cosmos DB, PostgreSQL, MySQL, Redis, and Storage
- Network: VNets, NSGs, load balancers, and Application Gateway
- Observability: Azure Monitor, Log Analytics, and Application Insights

The actual actions available depend on identity permissions, network reachability, enabled tools, and the selected run mode.

---

## 3. How Azure SRE Agent works

```mermaid
flowchart LR
    A[Alert, schedule, webhook, or chat] --> B[Main SRE Agent]
    B --> C[Gather context]
    C --> D[Logs, metrics, resources, code, incidents, knowledge]
    D --> E[Form and test hypotheses]
    E --> F[Use skills, tools, connectors, and custom agents]
    F --> G[Findings and proposed mitigation]
    G --> H{Run mode and permission gate}
    H -->|Review| I[Human approval]
    H -->|Autonomous and authorized| J[Execute action]
    I --> J
    J --> K[Verify outcome and record learning]
```

A typical incident flow is:

1. **Trigger:** An Azure Monitor incident arrives, or an operator starts a chat.
2. **Context gathering:** The agent queries live resources, logs, metrics, incident history, deployment data, repositories, and knowledge files.
3. **Reasoning:** It correlates evidence, develops hypotheses, and tests likely causes by calling tools.
4. **Specialization:** It can use a relevant skill or delegate focused work to custom agents.
5. **Recommendation:** It explains the likely root cause, impact, evidence, and proposed mitigations.
6. **Permission check:** Every tool call is evaluated against identity permissions, tool policy, hooks, and the configured run mode.
7. **Action:** In **Review** mode, write actions wait for approval. In **Autonomous** mode, an adequately permissioned agent can act without human approval.
8. **Verification and learning:** The agent validates recovery, updates the incident, and retains useful operational context.

### Security model in brief

- Each agent has an isolated sandbox for tool execution.
- A managed identity provides Azure access through RBAC.
- Short-lived credentials are supplied per tool call by an identity sidecar and are not placed in the reasoning context.
- Outbound calls pass through a validating network proxy.
- Agent operations can be sent to the customer's Application Insights resource for audit and troubleshooting.
- Reader access and Review mode are the recommended pilot starting point.

---

## 4. What is the scope of an agent?

There are three different scopes to understand.

### 4.1 Deployment scope

The SRE Agent resource itself is created in:

- One Azure tenant
- One owning subscription
- One resource group
- One supported Azure region

The deployment also uses or creates a managed identity, Application Insights, and usually a Log Analytics workspace.

### 4.2 Azure operational scope

The resources the agent can inspect or manage are determined by Azure RBAC assigned to its managed identity.

| Azure level | Supported approach | Practical meaning |
|---|---|---|
| Individual resource | Possible through direct RBAC, but usually too granular to operate | Narrowest reach; high administrative overhead |
| Resource group | First-class setup choice and recommended starting boundary | Access applies to resources in selected groups |
| Subscription | First-class setup choice for Reader access | Agent can discover and investigate all resources in selected subscriptions |
| Management group | Not presented as a first-class SRE Agent setup scope in current documentation | Azure RBAC can inherit from management-group assignments, but validate this design and use least privilege before enterprise rollout |
| Tenant | Not an automatic blanket scope | The agent is tenant-bound by identity; access must be explicitly granted to subscriptions/resources |
| Cross-tenant | Advanced design, not automatic | Requires delegated access, for example Azure Lighthouse, plus suitable RBAC and connector authentication |

The onboarding experience can add **subscriptions** or **resource groups**, including selections across subscriptions where the deploying user is allowed to create role assignments.

### 4.3 Connected-system scope

Azure RBAC does not govern every external system. GitHub, Azure DevOps, and custom MCP servers have their own authentication and authorization scopes.

Therefore:

> **Effective agent scope = Azure RBAC + connector permissions + network reachability + enabled tools + run mode.**

### Reader versus Privileged

| Permission level | Purpose | Recommended use |
|---|---|---|
| Reader | Query resources, configurations, logs, and metrics; no direct Azure modification | Start here for discovery, investigations, and pilots |
| Privileged | Allows authorized operational changes | Add only for tested use cases and tightly scoped resources |

Permission level and run mode solve different problems. RBAC determines whether an action is technically allowed; **Review** or **Autonomous** determines whether human approval is required before the action runs.

---

## 5. Is one agent enough for an entire subscription?

### Short answer

**Technically, often yes. Architecturally, it depends.** A single agent can monitor multiple resources and workloads in its configured scope, and Microsoft explicitly notes that consolidating workloads under one agent can reduce always-on cost.

### Start with one agent when

- The workloads have the same owning or on-call team.
- They share incident processes, observability, repositories, and runbooks.
- The same RBAC and autonomy policy is appropriate for all resources.
- They have similar data-residency and network requirements.
- A common operational knowledge base improves investigations.
- The pilot needs a simple, low-cost starting point.

### Use multiple agents when

- Production and nonproduction need strict isolation.
- Different teams own different services or budgets.
- Workloads need different privileged permissions or autonomy levels.
- Business units have different compliance, tenant, residency, or network boundaries.
- The knowledge, connectors, and instructions would become noisy or contradictory.
- A regulated or high-risk workload needs a smaller blast radius.
- Separate cost attribution or lifecycle management is required.

### Recommended enterprise pattern

Do not default to "one agent per resource" or "one agent for the whole tenant." Use an **application, platform, or operational ownership boundary**.

A sensible rollout is:

1. One Reader-mode agent for one production application or platform and its nonproduction counterpart.
2. Connect only the essential telemetry, code, incident system, and runbooks.
3. Measure investigation quality, AAU use, MTTR, false conclusions, and operator acceptance.
4. Add narrowly scoped write permissions and Review-mode mitigations.
5. Split or expand agents based on ownership, risk, context quality, and observed cost.

---

## 6. Main configuration options

| Option | Decision to make |
|---|---|
| Model provider | Anthropic or Azure OpenAI, subject to region, tenant eligibility, data-boundary needs, and current availability |
| Azure resources | Select resource groups or subscriptions and assign Reader or narrowly scoped privileged access |
| Run mode | **Review** for approval before actions; **Autonomous** for trusted automation |
| Incident platforms | Azure Monitor Alerts |
| Response plans | Filter by severity, service, incident type, or title, then route to a custom agent and run mode |
| Scheduled tasks | Define recurring health, compliance, cost, capacity, deployment, or SLA checks in natural language |
| Connectors | Add telemetry, code, knowledge, notifications, incident systems, and custom MCP services |
| Skills | Package repeatable procedures that the agent selects automatically when relevant |
| Custom agents | Add focused domain specialists with selected tools and optional handoff chains |
| Python tools | Implement custom calculations, transformations, and API logic |
| Knowledge files | Add architecture, runbooks, SOPs, postmortems, and service documentation |
| Memory | Retain synthesized operational learning across investigations |
| Hooks and tool permissions | Enforce deterministic or LLM-evaluated policy before or after tool execution |
| Network mode | Use unrestricted, limited, or VNet-integrated execution according to private endpoint and egress needs |
| Consumption limit | Set a monthly active-flow AAU allocation and monitor usage by thread type |

### Skills versus custom agents versus knowledge

| Use | Choose |
|---|---|
| A repeatable procedure the main agent should discover automatically | Skill |
| A specialist with focused instructions and tools | Custom agent |
| Reference material that should ground answers | Knowledge file |
| A connection to an external system or API | Connector or MCP server |
| A policy or lifecycle action around tool execution | Hook |

---

## 7. Governance and adoption checklist

Before enabling autonomous remediation, confirm:

- [ ] Named service owner and agent administrator
- [ ] Clear application or platform boundary
- [ ] Reader-first RBAC with least-privilege exceptions
- [ ] Review mode for new response plans and scheduled tasks
- [ ] Tested rollback and verification steps
- [ ] Incident filters that prevent irrelevant alerts from consuming agent time
- [ ] Curated architecture, runbooks, escalation rules, and known-failure guidance
- [ ] Connector identities scoped in their source systems
- [ ] Audit telemetry connected and reviewed
- [ ] VNet integration where private-only resources or controlled egress require it
- [ ] Monthly AAU limit and Azure Cost Management alerting
- [ ] Success measures: MTTR, investigation time, toil removed, approval rate, recurrence, and cost per resolved task

### Important limitations and considerations

- AI-generated diagnoses can be wrong or incomplete; validate evidence and proposed actions.
- English is currently the supported chat-interface language.
- Service and model availability vary by region and tenant configuration.
- Anthropic models have separate eligibility and data-boundary considerations; Azure OpenAI is the documented option for applicable EU Data Boundary requirements.
- Resources may be in regions different from the agent's deployment region, subject to permissions and connectivity.
- Stopping an agent stops active work but does **not** stop the fixed always-on charge; deleting it stops all SRE Agent billing.

---

## 8. Security posture scenario: accidentally exposed public ports

Azure SRE Agent can investigate public exposure when it has Reader access and a
focused prompt, custom agent, or scheduled task. It should complement Azure's
native prevention and posture controls, not replace them.

| Layer | Azure service | Responsibility |
|---|---|---|
| Prevent | Azure Policy at a management group or subscription | Deny prohibited public IPs, broad NSG rules, or public network access before deployment |
| Continuously assess | Azure Policy Audit and Defender for Cloud/Defender CSPM | Inventory noncompliance, recommendations, attack paths, and exposure risk |
| Detect changes | Azure Activity Log, Azure Monitor, or Event Grid | Trigger on NSG, firewall, public IP, ingress, or public-access changes |
| Investigate | Azure SRE Agent | Correlate effective reachability, resource context, owner, recent caller, and operational impact |
| Remediate | SRE Agent in Review mode or an approved automation workflow | Propose the least-disruptive fix, require approval, apply it with narrow RBAC, and verify the result |

Do not classify every public endpoint as a vulnerability. Evaluate the effective
path, source range, protocol and port, attached resource, environment, firewall or
WAF controls, and business intent. Public HTTP/HTTPS can be expected; management
ports, database ports, unrestricted Kubernetes APIs, and custom high ports usually
deserve stronger scrutiny.

### Starter-lab implementation

The starter lab includes a **public-exposure-auditor** custom agent with only
`RunAzCliReadCommands` and `GetAzCliHelp`. Its **audit-public-exposure** scheduled
task runs daily at 06:00 UTC and reports:

- Broad NSG inbound sources such as `Internet`, `*`, `0.0.0.0/0`, and `::/0`
- Public IP attachments and the resources they expose
- Public PaaS network access and unrestricted firewall or IP allowlists
- AKS services, ingress, load balancers, and public control-plane exposure
- Relevant Activity Log changes from the previous 24 hours, including caller attribution when available
- Severity, evidence, affected scope, and a least-disruptive remediation recommendation

The task is deliberately non-destructive. Run it from **Builder > Scheduled
tasks > audit-public-exposure > Run task now**, or select the custom agent and ask:

`Audit my authorized Azure scope for accidental public exposure. Show effective reachability, sensitive ports, recent change attribution, and prioritized remediation recommendations. Do not modify resources.`

---

## 9. Pricing

> **Pricing snapshot checked August 11, 2026. Always verify the Azure pricing page and your agreement before making a purchasing decision.**

Azure SRE Agent is billed in **Azure Agent Units (AAUs)**. Public US list pricing is currently **$0.10 per AAU** and has two components.

### 9.1 Always-on flow: fixed baseline

- Rate: **4 AAUs per agent-hour**
- Public US list cost: `4 AAUs x $0.10 = $0.40 per agent-hour`
- Approximate 30-day month: `4 x 24 x 30 = 2,880 AAUs = $288`
- Approximate 730-hour billing month: `4 x 730 = 2,920 AAUs = $292`

Always-on billing starts when the agent is created and continues until it is deleted. Stopping the agent does not remove this charge.

### 9.2 Active flow: variable, token-based usage

Active flow is charged whenever the agent is processing work, including chat, incidents, scheduled tasks, triggers, and asynchronous investigations. Waiting for human input is not active-flow usage.

Current documented AAUs per one million tokens:

| Model | Input | Output | Cache read | Cache write |
|---|---:|---:|---:|---:|
| Claude Opus 4.6 | 100 | 500 | 10 | 125 |
| GPT 5.3 Codex | 35 | 280 | 3.5 | 0 |
| GPT 5.2 | 35 | 280 | 3.5 | 0 |

Illustrative documented scenarios at public US list pricing:

| Scenario | Claude Opus 4.6 | GPT 5.3 Codex |
|---|---:|---:|
| Quick question | ~3.8 AAUs / **$0.38** | ~1.3 AAUs / **$0.13** |
| Incident investigation | ~35.3 AAUs / **$3.53** | ~11.7 AAUs / **$1.17** |
| Full remediation | ~86.5 AAUs / **$8.65** | ~30.1 AAUs / **$3.01** |

These are examples, not fixed task prices. Actual use depends on context size, task complexity, reasoning steps, tool results, caching, and the configured provider.

### 9.3 Example monthly estimate

For one agent in a 30-day month using GPT 5.3 Codex for 20 example incident investigations and 100 example quick questions:

| Component | Calculation | Estimate |
|---|---:|---:|
| Always-on | `2,880 AAUs x $0.10` | $288.00 |
| Investigations | `20 x 11.7 AAUs x $0.10` | $23.40 |
| Quick questions | `100 x 1.3 AAUs x $0.10` | $13.00 |
| **Estimated SRE Agent total** | **3,244 AAUs** | **$324.40/month** |

This estimate excludes separate charges that can include Azure Monitor ingestion and retention, Application Insights, Log Analytics queries, and data egress.

### 9.4 Azure Monitor and Log Analytics are separate meters

AAUs pay for the SRE Agent's availability and reasoning; they do not include the
cost of collecting or retaining evidence. A complete customer estimate is:

`SRE Agent always-on + SRE Agent active flow + observability data + integration costs`

Log Analytics normally charges each workspace for billable GB ingested. Other
possible meters include retention beyond the included interactive period,
queries against Basic or Auxiliary tables, search jobs, restore, export, alerts,
and Microsoft Sentinel when it is enabled. The source table's `_IsBillable` and
`_BilledSize` fields, or the workspace `Usage` table, provide the measured volume.
Some platform tables, including `AzureActivity`, `Heartbeat`, `Usage`, and
`Operation`, do not have an ingestion charge.

Log Analytics is not a universal prerequisite for every resource connected to
SRE Agent. Prefer this evidence order:

1. Use native metrics, Activity Log, Resource Health, live configuration APIs,
    and existing observability connectors when they answer the operational
    question without copying another full telemetry stream.
2. Reuse existing Application Insights, Log Analytics, or Kusto data instead
    of creating an SRE-Agent-specific duplicate.
3. Ingest only the resource-log categories and fields needed for detection,
    correlation, RCA, audit, or an approved remediation decision.
4. Keep alert-driving and frequently correlated signals in Analytics tables.
    Put verbose debugging or audit data that is queried infrequently in Basic
    tables where supported. Use Auxiliary tables for high-volume evidence that
    does not require log alerts or full interactive analytics.
5. Retain hot data only for the normal investigation window. Use long-term
    retention or an external archive only where compliance or incident history
    requires it.

For every onboarded signal, the platform team should agree an **ingestion contract** with the
customer: operational question, source, categories, expected GB/day, table plan,
retention, alert dependency, monthly budget, and owner. No source should be
enabled with an unbounded "all logs" setting merely because an agent might use
it later.

Primary controls are source-side sampling and filtering, Azure Monitor Agent
data collection rules, diagnostic-category selection, and ingestion-time
transformations. Filtering before data leaves the source is preferable. For
Analytics and Basic tables, filtering more than 50 percent with a cloud-side
transformation can incur a data-processing charge; Auxiliary tables charge for
incoming processing as well as retained ingestion. Treat a workspace daily cap
only as an emergency circuit breaker: collection can overshoot the cap, billed
data above it still costs money, and reaching it makes the agent and alerts blind
until collection resumes.

Track the actual billable volume by table and plan:

```kql
Usage
| where TimeGenerated > ago(32d)
| where StartTime >= startofday(ago(31d)) and EndTime < startofday(now())
| where IsBillable
| summarize BillableGB = sum(Quantity) / 1000.0 by DataType, Plan
| order by BillableGB desc
```

Set ingestion anomaly alerts and Azure Cost Management budgets before broad
onboarding. After measuring a stable baseline, evaluate an Analytics Logs
commitment tier only when sustained volume justifies the minimum commitment;
commitment discounts do not cover Basic or Auxiliary ingestion.

### 9.5 SRE Agent cost controls

- Set an active-flow monthly AAU allocation in **Settings > Agent consumption**.
- Filter incidents so only relevant alerts trigger investigations.
- Batch routine checks as scheduled tasks instead of frequent polling.
- Test prompts and automation in chat or the playground before scheduling them.
- Give the agent concise, high-quality context to avoid wasteful exploration.
- Consolidate related workloads when governance permits, because every additional agent has an always-on baseline.
- Delete unused agents; stopping them removes active usage but not the baseline charge.

There is currently no SRE Agent free tier. Azure offers and agreement discounts may change the effective price.

---

## 10. Suggested live demo flow

### Demo objective

Show the agent moving from a symptom to evidence, root cause, controlled mitigation, and verification in one investigation thread.

### Before the demo

- Confirm the agent is running and its consumption limit has headroom.
- Confirm Azure resources, telemetry, repository, and incident connectors are healthy.
- Use Reader access or Review mode for the first demonstration.
- Prepare a reversible failure with enough telemetry to diagnose.
- Keep a known-good recovery command available as a fallback.
- Open **Settings > Managed resources**, **Builder > Connectors**, and the incident/chat view in separate tabs.

### Talk track and actions

1. **Show the agent resource:** Point out its owning subscription, resource group, region, model provider, and managed identity.
2. **Show managed resources:** Explain that these RBAC assignments, not the agent resource group, define Azure reach.
3. **Show context:** Display connected telemetry, code repository, and knowledge/runbook content.
4. **Introduce the failure:** Trigger an application, VM, AKS, database, deployment, or configuration issue.
5. **Start investigation:** Use the incident trigger or ask:  
   `Investigate the current service degradation. Identify impact, correlate recent changes, test the most likely causes, and propose the lowest-risk mitigation. Do not make changes without approval.`
6. **Inspect the evidence:** Highlight log queries, metrics, resource state, deployment correlation, and cited code or runbooks.
7. **Review the proposal:** Ask for alternatives, risk, rollback, and success criteria.
8. **Approve one safe action:** Demonstrate the permission gate and auditability.
9. **Verify recovery:** Ask the agent to confirm health against the original symptom and summarize the incident timeline.
10. **Show learning and automation:** Turn the proven procedure into a skill, response plan, or scheduled check.
11. **Close with consumption:** Show the thread's AAU usage and explain fixed versus variable cost.

### Useful follow-up prompts

- `What evidence would falsify your root-cause hypothesis?`
- `Show the affected resource scope and any dependencies you have not checked.`
- `Compare this incident with similar previous investigations.`
- `Propose a mitigation, rollback plan, verification checks, and expected customer impact.`
- `What permissions would be required to automate this safely?`
- `Create a post-incident summary with timeline, root cause, mitigation, and prevention actions.`

---

## 11. Questions the audience is likely to ask

### Does the agent replace the on-call engineer?

No. It reduces investigation and execution toil, preserves context, and can automate approved workflows. Humans remain responsible for service ownership, risk decisions, governance, and exceptional situations.

### Can it make changes automatically?

Yes, when the agent has sufficient RBAC and the response plan or task uses Autonomous mode. Start new workflows in Review mode and promote only well-tested, reversible actions.

### Can it work outside Azure?

Yes. MCP and managed connectors can integrate external observability, incident, collaboration, code, and custom systems. Access depends on each connector's credentials and network path.

### Can it see every resource in the subscription by default?

No. It sees resources authorized through its managed identity. Subscription-wide Reader can be granted, or access can be limited to selected resource groups.

### Can one agent access multiple subscriptions?

Yes. Add selected subscriptions or resource groups and grant the agent's managed identity the required RBAC on each scope.

### Can one agent cover multiple tenants?

Not by default. Cross-tenant operation is an advanced scenario that requires explicit delegation, such as Azure Lighthouse, plus RBAC and connector configuration.

### Does stopping an agent stop billing?

It stops active processing and active-flow consumption, but the fixed always-on charge continues. Delete the agent to stop SRE Agent billing completely.

### Is customer data used to train the models?

Microsoft states that prompts and completions are not used to train the base models. That is separate from abuse-monitoring retention and from stateful features intentionally storing data. Review the model provider, abuse-monitoring status, application logging, agent storage, and organizational compliance requirements for each deployment.

---

## 12. Recommended pilot

Run a two-to-four-week pilot around one well-observed service:

1. Deploy one agent in a supported region.
2. Grant Reader access to only the application's resource groups.
3. Connect Azure Monitor/Application Insights, the source repository, and the incident platform.
4. Add the architecture document, top runbooks, escalation policy, and recent postmortems.
5. Use Review mode and test five to ten representative incidents.
6. Add one low-risk scheduled task and one narrowly filtered response plan.
7. Measure MTTR, engineer time saved, diagnostic accuracy, recurrence, operator approval rate, and AAU cost.
8. Decide whether to expand the scope, add privileged actions, or split agents by ownership boundary.

A successful pilot proves not merely that the agent can answer questions, but that it can produce repeatable, evidence-grounded operational outcomes within acceptable cost and risk.

---

## Official references

- [Azure SRE Agent product page](https://www.azure.com/sreagent)
- [Azure SRE Agent documentation](https://learn.microsoft.com/azure/sre-agent/)
- [Product overview](https://learn.microsoft.com/azure/sre-agent/overview)
- [Create and set up an agent](https://learn.microsoft.com/azure/sre-agent/create-and-set-up)
- [Manage permissions](https://learn.microsoft.com/azure/sre-agent/manage-permissions)
- [Security overview](https://learn.microsoft.com/azure/sre-agent/security-overview)
- [Azure Policy overview](https://learn.microsoft.com/azure/governance/policy/overview)
- [Organize resources with management groups](https://learn.microsoft.com/azure/governance/management-groups/overview)
- [Defender for Cloud environment settings](https://learn.microsoft.com/azure/defender-for-cloud/environment-settings)
- [Data, privacy, and security for Azure Direct Models](https://learn.microsoft.com/azure/ai-foundry/responsible-ai/openai/data-privacy)
- [Apply for modified abuse monitoring](https://learn.microsoft.com/azure/ai-foundry/responsible-ai/openai/limited-access)
- [Connectors](https://learn.microsoft.com/azure/sre-agent/connectors)
- [Custom agents](https://learn.microsoft.com/azure/sre-agent/sub-agents)
- [Incident response plans](https://learn.microsoft.com/azure/sre-agent/incident-response-plans)
- [Scheduled tasks](https://learn.microsoft.com/azure/sre-agent/scheduled-tasks)
- [Pricing and billing](https://learn.microsoft.com/azure/sre-agent/pricing-billing)
- [Azure SRE Agent pricing page](https://azure.microsoft.com/pricing/details/sre-agent/)
- [Azure Network Watcher Connection Monitor](https://learn.microsoft.com/azure/network-watcher/connection-monitor-overview)
- [Azure Network Watcher Connection Troubleshoot](https://learn.microsoft.com/azure/network-watcher/connection-troubleshoot-overview)
- [Azure Virtual Network Manager Network Verifier](https://learn.microsoft.com/azure/virtual-network-manager/concept-virtual-network-verifier)
- [Verify resource reachability with Network Verifier](https://learn.microsoft.com/azure/virtual-network-manager/how-to-verify-reachability-with-virtual-network-verifier)
- [Official labs and community resources](https://github.com/microsoft/sre-agent)

---

*This document is a demo aid, not a contractual description of service behavior or price. Azure features, model availability, regions, limits, and rates can change. Validate the portal, Microsoft Learn, Azure pricing calculator, and your Azure agreement before production rollout.*
