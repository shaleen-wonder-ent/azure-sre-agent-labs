# Enterprise Operations Terraform

This Terraform is an overlay for the existing `labs/zava-learning` deployment. It creates the SRE Agent, identity and RBAC, hub networking, private diagnostics VM, monitoring, alerts, and optional scenario resources. It deliberately does not import or recreate the Zava application, Application Gateway, VNet, Log Analytics workspace, or Application Insights component.

The approved source plan is [../.azure/infrastructure-plan.json](../.azure/infrastructure-plan.json).

## Default deployment

The core profile creates:

- one overlay resource group in `centralindia`;
- a hub VNet, private diagnostics `/24`, NSG, route table, NAT Gateway, and Standard static outbound IP;
- bidirectional peering to the existing Zava VNet;
- a private Ubuntu 24.04 `Standard_B2s` VM with Trusted Launch, secure boot, vTPM, managed boot diagnostics, and system identity;
- Azure Monitor Agent, Network Watcher Agent, a DCR, and DCR association;
- Connection Monitor tests to the Zava public Application Gateway and an optional private target;
- subscription Activity Log export to the existing Zava Log Analytics workspace;
- an action group and four focused log alerts;
- a dedicated UAMI and Azure SRE Agent preview resource;
- Reader and Monitoring Reader on the Zava and overlay resource groups plus Log Analytics Reader on the workspace;
- Azure SRE Agent Administrator for the deploying principal or a supplied principal.

The agent receives no write-capable Azure role by default. The SRE configuration runner installs an always-on blocking approval hook before any operational write.

## Existing resources required

Deploy `labs/zava-learning` first, or select the subscription where it already exists. Set these values in `terraform.tfvars`:

- `zava_resource_group_name`
- `zava_virtual_network_name`
- `zava_log_analytics_workspace_name`
- `zava_application_insights_name`
- `zava_application_gateway_name`
- `admin_ssh_public_key`

The current Azure CLI context used while this module was generated did not contain a Zava deployment. Terraform therefore fails at plan time until these names resolve. This is intentional and prevents an accidental duplicate workload.

## Prerequisites

- Terraform 1.9 or later; generation was validated with Terraform 1.15.8.
- Azure CLI authenticated to the deployment tenant.
- PowerShell 7 or later for post-deploy SRE configuration.
- Registered providers: `Microsoft.App`, `Microsoft.Authorization`, `Microsoft.Compute`, `Microsoft.Insights`, `Microsoft.ManagedIdentity`, `Microsoft.Network`, `Microsoft.OperationalInsights`, and optional `Microsoft.Sql`.
- A Network Watcher in the target region. Defaults reference `NetworkWatcher_centralindia` in `NetworkWatcherRG`; set `create_network_watcher = true` only when the target subscription has no regional watcher.

The deployment principal needs:

- permission to create a resource group and core resources in the primary subscription;
- permission to create a peering child on the existing Zava VNet;
- permission to create subscription diagnostic settings;
- Role Based Access Control Administrator or equivalent role-assignment permission on the overlay and Zava scopes;
- read access to the existing workspace, Application Insights, Application Gateway, VNet, and resource group.

Optional Entra diagnostics require Contributor at `/providers/Microsoft.aadiam`; granting it requires root-scope User Access Administrator. Optional secondary-subscription deployment requires the equivalent permissions in that existing subscription.

## State backend

`backend.tf` declares an Azure Storage backend without embedding environment-specific values. Create the state resource group, storage account, and private container through your platform bootstrap, then create ignored `backend.hcl` values from [backend.hcl.example](backend.hcl.example). Use Entra authentication and do not place storage keys in the file.

For a local workshop state only, initialize with `-backend=false`. Do not use local state for shared or long-lived environments.

## Initialize and validate

From this directory:

```powershell
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
```

For local-state validation:

```powershell
terraform init -backend=false
terraform validate
```

## Plan and apply the core profile

Review `terraform.tfvars`, confirm the active subscription, and run:

```powershell
az account show --query '{subscription:id,name:name,tenant:tenantId}' -o table
terraform plan -out=core.tfplan
terraform apply core.tfplan
```

The plan enforces exact IPv4 range checks so the hub cannot overlap any existing Zava VNet range and the diagnostics and SQL MI subnets cannot overlap each other or fall outside the hub.

After apply, configure the SRE Agent data plane from the lab root:

```powershell
pwsh ./scripts/Configure-SreAgent.ps1
```

The runner is idempotent and performs these operations:

1. Resolves deployed IDs and the SRE Agent endpoint from Terraform outputs.
2. Confirms Azure Monitor as the incident platform.
3. Creates or updates Log Analytics and Azure Monitor connectors.
4. Installs the `enterprise-operations` skill for all 13 scenarios.
5. Uploads the implementation guide and prompt pack as indexed knowledge.
6. Applies the always-on operational write-approval hook.
7. Creates the review-mode enterprise incident response plan.
8. Replaces six scheduled operational reports by stable name and verifies the final inventory.

The verification report is written to `sre-config/verification-report.json` and ignored by Git.

## Optional modules

### Cost and security readers

```hcl
enable_cost_management_reader = true
enable_security_reader        = true
```

These are read-only but use subscription scope because the corresponding APIs aggregate at subscription level.

### Approved remediation roles

`remediation_role_definition_ids` accepts reviewed role definition resource IDs and assigns them only at the Zava resource-group scope. Keep the set empty for the default lab. The global hook does not replace Azure least privilege; both controls are required.

### Entra diagnostics

```hcl
enable_entra_diagnostics = true
```

This exports audit, user sign-in, noninteractive sign-in, service-principal sign-in, managed-identity sign-in, and provisioning logs. Confirm tenant permissions and licensing before planning.

### SQL Managed Instance

SQL MI is disabled because it has material monthly cost and can take many hours to create or delete. Before enabling it, confirm Central India quota, pricing, the globally unique name, and teardown timing.

```hcl
enable_sql_managed_instance = true
sqlmi_name                   = "globally-unique-lowercase-name"
sqlmi_vcores                 = 4
sqlmi_storage_size_gb        = 32
sqlmi_license_type           = "LicenseIncluded"
```

Supply the password only through a secure terminal or CI secret store:

```powershell
$env:TF_VAR_sqlmi_administrator_password = Read-Host -MaskInput 'SQL MI administrator password'
terraform plan -out=sqlmi.tfplan
```

The module creates an exclusive delegated `/24`, NSG, and route table. It does not associate NAT Gateway because Azure SQL Managed Instance does not support NAT Gateway on its subnet. The public data endpoint is disabled and only the VNet-local FQDN is output.

### Second subscription

Terraform cannot create an Azure subscription. Supply an existing same-tenant subscription:

```hcl
enable_secondary_subscription = true
secondary_subscription_id      = "00000000-0000-0000-0000-000000000000"
```

The module creates one test resource group, grants the agent Reader and Monitoring Reader only on that group, and exports the secondary Activity Log to the primary workspace. Both subscriptions must belong to the same Microsoft Entra tenant.

## Network fault exercise

`enable_network_fault_route = true` adds a `0.0.0.0/0` route with next hop `None` to the diagnostics subnet. This intentionally breaks its outbound path and should be enabled only for scenario 2. Set it back to `false` and apply to restore the baseline.

The existing Application Gateway subnet is never modified.

## Verification

Infrastructure checks:

```powershell
terraform fmt -check -recursive
terraform validate
terraform plan -detailed-exitcode
```

Runtime checks:

```powershell
terraform output
az rest --method get --url "https://management.azure.com$(terraform output -raw connection_monitor_id)?api-version=2022-07-01"
pwsh ../scripts/Configure-SreAgent.ps1 -SkipKnowledgeUpload
```

Use the copy-ready investigations in [../prompts/scenario-prompts.md](../prompts/scenario-prompts.md). Optional scenarios should report missing permissions or resources as coverage gaps until their modules are enabled.

## Teardown

Disable fault injection first. SQL MI deletion can take up to 24 hours.

```powershell
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

The Zava workload and remote-state storage are references, not owned resources, and remain intact. The reverse peering child created in the Zava VNet is owned by this state and is removed.

## Known boundaries

- `Microsoft.App/agents@2025-05-01-preview` is provisioned with AzAPI because AzureRM does not expose it. Provider validation for that body is disabled, but the shape is grounded in the repository's verified Zava Bicep deployment.
- Skills, hooks, response plans, tasks, connectors, and knowledge are data-plane objects. The checked-in runner verifies them but Terraform cannot fully track them in state.
- Defender for Cloud, Sentinel, Azure Firewall, DDoS Network Protection, and Bastion are not default resources. They can enrich a workshop but are not required for the 13-scenario core profile.
- A real 30-day availability or capacity claim requires sufficient retained history. The agent must report short retention as inconclusive rather than inventing a result.
