# Azure SRE Agent — Regions, Data Residency & Pricing

**Customer transparency reference.** Answers the two questions customers ask before adopting the
agent: *"Where does my data go, and what will the agent access or keep?"* and *"What does it cost?"*

> **Verified 2026-08-26** against Microsoft Learn. Regions, models, and rates change — always confirm
> against the live sources linked at the bottom before quoting figures to a customer.

---

## 1. Where the agent runs (and what that means for your data)

An SRE Agent is an Azure resource you create in **one region** and **one subscription**. Two facts
matter most for data-residency conversations:

- **The agent's region only determines where the agent *compute* runs** — not what it can reach.
- **With RBAC on its managed identity, the agent can read and act on resources in *any* region or
  subscription you grant it.** So the agent's deployment region is **not** the same as its operational
  scope.

**Practical implication:** if Azure SRE Agent is **not yet available in your country/region**, and you
deploy the agent in another region so it can manage your resources, then the agent's reasoning and
tool-execution (sandbox) processing happens in **that other region**. Tool results and their
summaries are processed and persisted where the *agent* lives, not where your resources live. If you
have hard data-residency obligations and no compliant agent region exists yet, **wait for a supported
region** (you can [request one](https://github.com/microsoft/sre-agent/issues/new?labels=region-request&title=New+region+request)) or restrict what you connect.

### Supported regions (as of 2026-08-26)

| Geography | Regions |
|---|---|
| United States | Central US, East US 2, North Central US, West Central US, West US 2, West US 3 |
| Canada | Canada Central |
| Europe | France Central, Italy North, Spain Central, Sweden Central, UK South |
| Asia Pacific | Australia East, East Asia, Japan East, Southeast Asia |
| Asia (Central) | Korea Central |
| Africa | South Africa North |

If the **Region** dropdown is empty when you create an agent at <https://sre.azure.com>, your
subscription isn't registered yet — [submit a registration request](https://github.com/microsoft/sre-agent/issues/new?labels=registration&title=Subscription+registration+request).
Each agent is fixed to a single region; you can't change it after creation (create a new agent instead).

> **Regional sandbox isolation:** sandbox placement respects regional boundaries. For example,
> East US 2 sandboxes stay within Central US, North Central US, or Canada Central. For locked-down
> workloads, the agent supports **VNet-integrated execution** and private network access.

---

## 2. What the agent does — and does **not** — keep

This is the core of the customer's apprehension. Be precise:

**The agent does NOT copy your raw data into a separate store.** When it investigates, it queries your
data sources (logs, metrics, API responses) but does **not** write those raw results to a separate
data store. It serializes the chat and tool messages — including **result summaries** — into the
conversation thread.

### What is persisted

| Data | Where | Retention | Purpose |
|---|---|---|---|
| **Conversation threads** | Agent database | Until you delete them | Chat history and investigation records |
| **Session insights** | Agent database + blob storage | Persistent | *Synthesized* learnings (symptoms, resolution steps, root causes) — not raw copies |
| **Memory files** | Blob storage | Persistent across sessions | Synthesized knowledge, team context, repo instructions |
| **Thread files** | Blob storage | Tied to the thread's lifetime | Your uploads and generated reports |

Session insights are **synthesized summaries, not raw data copies**. The agent stores serialized tool
messages, which *may* include result excerpts or summaries, as part of the thread history — it does
not independently persist complete raw query results.

### What keeps you in control

| Control | What it means |
|---|---|
| **Per-customer isolation** | Dedicated sandbox (micro-VM), separate database, separate blob storage, per-agent network proxy, and a per-agent managed identity. **No data, compute, or credentials are shared between agents or customers.** |
| **RBAC scoping** | The agent's managed identity is scoped to the **resource groups you select** — it can only reach what you grant. |
| **Human approval (Review mode)** | The agent proposes changes; **nothing that writes deploys without your approval**. A permission gate evaluates every tool call before it runs. |
| **Secretless credentials** | An isolated identity sidecar issues short-lived, per-call tokens; credentials never enter the reasoning context and aren't cached after on-behalf-of actions. |
| **Your telemetry, your workspace** | Operational telemetry flows to the **Application Insights instance you own**, created in your subscription. |
| **Encryption** | Azure-managed encryption at rest; HTTPS for all external communication. Outbound access is validated by a network proxy limited to known service domains. |

> **Auto-created in your subscription** when you create an agent: an Application Insights instance, a
> Log Analytics workspace, and a managed identity. You own and can manage these.
>
> **Also note:** English is the only supported chat language, and availability varies by region and
> tenant. See the [Microsoft privacy statement](https://www.microsoft.com/privacy/privacystatement)
> for how Microsoft handles data.

---

## 3. Pricing

Billing is measured in **Azure Agent Units (AAUs)** — a standard unit of agentic processing. Your bill
has **two parts**: a fixed baseline and a variable, token-based usage charge.

> This is the **agent runtime** cost. It is separate from **telemetry ingestion** cost (what you send
> to Log Analytics), which is covered in
> [AZURE-SRE-AGENT-COST-CONSUMPTION.md](AZURE-SRE-AGENT-COST-CONSUMPTION.md).
>
> Prices below are the **listed examples** from the Azure pricing page and are **estimates only** —
> actual price per AAU varies by region, currency, and agreement. Confirm on the
> [pricing page](https://azure.microsoft.com/pricing/details/sre-agent/) / [calculator](https://azure.microsoft.com/pricing/calculator/?service=sre-agent).

### 3.1 Fixed baseline — always-on flow

You pay a fixed rate for as long as the agent **exists** (from creation until you **delete** it),
regardless of whether it is actively working.

| Component | Rate | Listed example |
|---|---|---|
| Always-on flow | **4 AAUs per agent-hour** | ≈$0.10 per AAU → **≈$0.40 per hour, per agent** |

New customers can [evaluate SRE Agent](https://aka.ms/sre-agent-trial) with the **always-on cost waived**.

### 3.2 Variable — active flow (token-based, on demand)

You pay **active flow AAUs only while the agent is actively processing work** (chat questions,
incident automation, scheduled tasks, background investigations). **Waiting for your approval is not
billed.** The counter **resets at the start of each calendar month.**

**Formula — tokens to AAUs.** Every task meters four token types independently:

```
active-flow AAUs (task) =
    (input_tokens       / 1,000,000) × input_rate
  + (output_tokens      / 1,000,000) × output_rate
  + (cache_read_tokens  / 1,000,000) × cache_read_rate
  + (cache_write_tokens / 1,000,000) × cache_write_rate
```

**AAU rates per 1 million tokens.** You choose the model **provider** at the agent level — SRE Agent
offers **Anthropic** (Claude models) and **Azure OpenAI** (GPT models, served through Microsoft
Foundry). The provider/model you pick sets your rates:

| Provider | Model | Input | Output | Cache read | Cache write |
|---|---|---:|---:|---:|---:|
| Anthropic | Claude Opus 4.6 | 100 | 500 | 10 | 125 |
| Azure OpenAI | GPT 5.3 Codex | 35 | 280 | 3.5 | 0 |
| Azure OpenAI | GPT 5.2 | 35 | 280 | 3.5 | 0 |

*(Specific model versions and rates change over time; Azure may add more. Confirm the current list in
your agent's settings and on the pricing page.)*

**Worked example — a "quick question" on Claude Opus 4.6:**

| Token type | Tokens | Rate / 1M | AAUs |
|---|---:|---:|---:|
| Input | 20K | 100 | 2.000 |
| Output | 2K | 500 | 1.000 |
| Cache read | 15K | 10 | 0.150 |
| Cache write | 5K | 125 | 0.625 |
| **Total** | | | **3.775 AAUs** |

**Typical task costs** (rough AAUs; complexity drives token use):

| Scenario | Claude Opus 4.6 | GPT 5.3 Codex |
|---|---:|---:|
| Quick question ("show me recent alerts") | ≈3.8 | ≈1.3 |
| Incident investigation (automated from Azure Monitor) | ≈35.3 | ≈11.7 |
| Full remediation ("diagnose and fix the failing deployment") | ≈86.5 | ≈30.1 |

### 3.3 End-to-end example — "report all under-utilized VMs"

> **Prompt:** *"Generate a report of all under-utilized VMs in the subscription over the last 30 days."*

**The important part:** active flow is metered on the **tokens** the task consumes — **not** on the
roughly 3 minutes it runs. A longer run costs more only if it does more work (more tool calls / more data =
more tokens). Time the agent spends **waiting for your approval is never billed**.

This is a read-only **investigation + report** task (the agent plans, runs several metric / Resource
Graph queries across your VMs, aggregates, and writes a report), so its token profile is comparable to
Microsoft's *incident-investigation* example. Illustrative token counts and the AAU math:

| Token type | Tokens | Opus 4.6 rate/1M | Opus AAUs | GPT 5.3 Codex rate/1M | GPT AAUs |
|---|---:|---:|---:|---:|---:|
| Input (prompt, tool results, context) | 200K | 100 | 20.00 | 35 | 7.00 |
| Output (the report + reasoning) | 15K | 500 | 7.50 | 280 | 4.20 |
| Cache read (repeated context) | 150K | 10 | 1.50 | 3.5 | 0.53 |
| Cache write (context cached for reuse) | 50K | 125 | 6.25 | 0 | 0.00 |
| **Active-flow total** | | | **≈35.3 AAU** | | **≈11.7 AAU** |

**Turn AAU into money** (using the ≈$0.10/AAU listed example — confirm your region/currency):

| | Claude Opus 4.6 | GPT 5.3 Codex |
|---|---:|---:|
| Active flow (this one task) | ≈35.3 AAU → **≈$3.53** | ≈11.7 AAU → **≈$1.17** |
| Always-on during the ≈3-min run | 4 AAU/hr × 0.05 hr = 0.2 AAU → **≈$0.02** | ≈$0.02 |

The always-on charge (4 AAU/hr) accrues in the background whether or not you run this task — the ≈$0.02
above is just the slice that overlaps the run. So the **marginal cost of this report ≈ its active-flow
figure** (≈$3.5 on Opus, ≈$1.2 on GPT). Run it as a **scheduled task** with a VM-rightsizing skill to
keep the agent grounded and concise, which trims tokens on every run.

### 3.4 Estimating your monthly cost

```
monthly cost ≈ (4 AAUs/hour × hours the agent exists)          ← always-on, fixed
             + (sum of active-flow AAUs for all tasks in month)  ← usage
             ────────────────────────────────────────────────
             × your price per AAU (region/currency dependent)
```

One agent can cover **multiple workloads** within its scope — consolidating reduces always-on cost
versus running many agents.

### 3.5 Keeping cost predictable

- **Monthly active-flow limit** (Settings → Agent consumption): set a cap between **500 and 1,000,000 AAUs**. On hitting it, the agent becomes unavailable for chat/actions until next month; **always-on still bills**.
- **Billing impact by action:**

  | Action | Active flow | Always-on | Resume |
  |---|---|---|---|
  | Hit budget limit | Stops | Still billed | Auto-resets next month |
  | **Stop** agent | Stops | Still billed | Settings → Basics → **Start** |
  | **Delete** agent | Stops | **Stops** | Create a new agent |

- Track spend in the SRE Agent portal (Settings → Agent consumption) and in **Azure Cost Management**.
- Reduce active-flow tokens by adding skills/knowledge, filtering incidents with response plans,
  batching with scheduled tasks, and testing prompts in chat before automating.

---

## References

| Topic | Source |
|---|---|
| Supported regions | <https://learn.microsoft.com/azure/sre-agent/supported-regions> |
| Security & data residency | <https://learn.microsoft.com/azure/sre-agent/security-overview> |
| Pricing & billing (AAU model) | <https://learn.microsoft.com/azure/sre-agent/pricing-billing> |
| Pricing page & calculator | <https://azure.microsoft.com/pricing/details/sre-agent/> |
| Overview & considerations | <https://learn.microsoft.com/azure/sre-agent/overview> |
| Microsoft privacy statement | <https://www.microsoft.com/privacy/privacystatement> |

> This document paraphrases Microsoft Learn as of 2026-08-26. It is guidance, not a contract. For
> commitments, rely on the live Microsoft documentation, your agreement, and the Microsoft Product Terms.
