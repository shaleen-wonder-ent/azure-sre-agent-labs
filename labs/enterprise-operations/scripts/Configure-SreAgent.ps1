[CmdletBinding()]
param(
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot '..\infra'),
    [string]$Scope,
    [string]$SecondarySubscriptionId,
    [switch]$SkipKnowledgeUpload
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$labRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$skillPath = Join-Path $labRoot 'sre-config\skills\enterprise-operations\SKILL.md'
$sqlMiSkillPath = Join-Path $labRoot 'sre-config\skills\sqlmi-performance\SKILL.md'
$tasksPath = Join-Path $labRoot 'sre-config\scheduled-tasks.json'
$guidePath = Join-Path $labRoot 'docs\use-case-implementation-guide.md'
$promptsPath = Join-Path $labRoot 'prompts\scenario-prompts.md'
$reportPath = Join-Path $labRoot 'sre-config\verification-report.json'

function Write-Step([string]$Message) {
    Write-Host "`n$Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Get-AzureToken([string]$Resource) {
    $token = az account get-access-token --resource $Resource --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $token) {
        throw "Could not obtain an Azure token for $Resource. Run 'az login' and select the deployment subscription."
    }
    return $token
}

function Invoke-AgentApi {
    param(
        [Parameter(Mandatory)] [ValidateSet('Get', 'Put', 'Post', 'Delete')] [string]$Method,
        [Parameter(Mandatory)] [string]$Path,
        [object]$Body
    )

    $headers = @{ Authorization = "Bearer $(Get-AzureToken 'https://azuresre.dev')" }
    $parameters = @{
        Uri         = "$script:agentEndpoint$Path"
        Headers     = $headers
        Method      = $Method
        ErrorAction = 'Stop'
    }

    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 12 }
    }

    return Invoke-RestMethod @parameters
}

function Invoke-ArmApi {
    param(
        [Parameter(Mandatory)] [ValidateSet('Get', 'Put', 'Patch')] [string]$Method,
        [Parameter(Mandatory)] [string]$Url,
        [object]$Body
    )

    $parameters = @{
        Uri         = $Url
        Headers     = @{ Authorization = "Bearer $(Get-AzureToken 'https://management.azure.com/')" }
        Method      = $Method
        ErrorAction = 'Stop'
    }

    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = $Body | ConvertTo-Json -Depth 12
    }

    return Invoke-RestMethod @parameters
}

function Get-Collection([object]$Response) {
    if ($null -eq $Response) { return @() }
    if ($Response.PSObject.Properties.Name -contains 'value') { return @($Response.value) }
    if ($Response.PSObject.Properties.Name -contains 'files') { return @($Response.files) }
    return @($Response)
}

Write-Step '[1/8] Reading deployed Terraform outputs'
$terraformPath = (Resolve-Path $TerraformDirectory).Path
Push-Location $terraformPath
try {
    $outputText = terraform output -json
    if ($LASTEXITCODE -ne 0 -or -not $outputText) {
        throw 'terraform output failed. Apply the approved infrastructure before configuring the SRE Agent data plane.'
    }
    $outputs = $outputText | ConvertFrom-Json
}
finally {
    Pop-Location
}

$agentId = [string]$outputs.sre_agent_id.value
$agentName = [string]$outputs.sre_agent_name.value
$agentEndpointOutput = [string]$outputs.sre_agent_endpoint.value
$agentIdentityId = [string]$outputs.sre_agent_identity_id.value
$workspaceId = [string]$outputs.zava_log_analytics_workspace_id.value
$zavaResourceGroupId = [string]$outputs.zava_resource_group_id.value
$primarySubscriptionId = [string]$outputs.primary_subscription_id.value

if (-not $agentId -or -not $agentName -or -not $workspaceId) {
    throw 'Required Terraform outputs are missing: sre_agent_id, sre_agent_name, or zava_log_analytics_workspace_id.'
}

if (-not $agentEndpointOutput) {
    $agentEndpointOutput = az resource show --ids $agentId --api-version 2025-05-01-preview --query properties.agentEndpoint -o tsv
}
if (-not $agentEndpointOutput) {
    throw "The SRE Agent endpoint is not available for $agentId. Verify provisioning completed."
}

$script:agentEndpoint = $agentEndpointOutput.TrimEnd('/')
if (-not $Scope) { $Scope = $zavaResourceGroupId }
$subscriptionIds = @($primarySubscriptionId)
if ($SecondarySubscriptionId) { $subscriptionIds += $SecondarySubscriptionId }

Write-Ok "Agent: $agentName"
Write-Ok "Endpoint: $script:agentEndpoint"
Write-Ok "Scope: $Scope"

Write-Step '[2/8] Ensuring Azure Monitor incident configuration'
$agentPatch = @{
    properties = @{
        incidentManagementConfiguration = @{
            type           = 'AzMonitor'
            connectionName = 'azmonitor'
        }
        experimentalSettings = @{
            EnableWorkspaceTools = $true
        }
    }
}
Invoke-ArmApi -Method Patch -Url "https://management.azure.com$agentId`?api-version=2025-05-01-preview" -Body $agentPatch | Out-Null
az resource wait --ids $agentId --custom "properties.provisioningState=='Succeeded'" --interval 10 --timeout 600
if ($LASTEXITCODE -ne 0) {
    throw 'SRE Agent did not return to Succeeded after its incident configuration update.'
}
Write-Ok 'Azure Monitor incident platform is configured.'

Write-Step '[3/8] Creating Azure Monitor and Log Analytics connectors'
$workspaceName = ($workspaceId -split '/')[-1]
$connectorBase = "https://management.azure.com$agentId/connectors"
$connectors = @(
    @{
        Name = 'log-analytics'
        Body = @{
            properties = @{
                dataConnectorType = 'LogAnalytics'
                dataSource = $workspaceId
                extendedProperties = @{
                    armResourceId = $workspaceId
                    resource = @{ name = $workspaceName }
                }
                identity = 'system'
            }
        }
    },
    @{
        Name = 'azure-monitor'
        Body = @{
            properties = @{
                dataConnectorType = 'MonitorClient'
                dataSource = 'n/a'
                identity = 'system'
            }
        }
    }
)
foreach ($connector in $connectors) {
    Invoke-ArmApi -Method Put -Url "$connectorBase/$($connector.Name)?api-version=2025-05-01-preview" -Body $connector.Body | Out-Null
    Write-Ok "Connector: $($connector.Name)"
}

Write-Step '[4/8] Installing the enterprise operations skill'
if (-not (Test-Path $skillPath)) { throw "Skill file not found: $skillPath" }
$skillBody = @{
    name = 'enterprise-operations'
    type = 'Skill'
    properties = @{
        description = 'Evidence-first Azure operations for 13 incident, reporting, capacity, cost, identity, security, deployment, and estate-health scenarios.'
        tools = @('SearchMemory', 'QueryLogAnalyticsByWorkspaceId', 'RunAzCliReadCommands', 'GetAzCliHelp')
        skillContent = Get-Content -Raw $skillPath
        additionalFiles = @(
            @{ filePath = 'scenario-prompts.md'; content = Get-Content -Raw $promptsPath },
            @{ filePath = 'use-case-implementation-guide.md'; content = Get-Content -Raw $guidePath }
        )
    }
}
Invoke-AgentApi -Method Put -Path '/api/v2/extendedAgent/skills/enterprise-operations' -Body $skillBody | Out-Null
Write-Ok 'Skill: enterprise-operations'

if (-not (Test-Path $sqlMiSkillPath)) { throw "Skill file not found: $sqlMiSkillPath" }
$sqlMiSkillBody = @{
    name = 'sqlmi-performance'
    type = 'Skill'
    properties = @{
        description = 'Read-only SQL MI performance analysis using Azure Monitor and operator-supplied Query Store and DMV evidence.'
        tools = @('SearchMemory', 'QueryLogAnalyticsByWorkspaceId', 'RunAzCliReadCommands', 'GetAzCliHelp')
        skillContent = Get-Content -Raw $sqlMiSkillPath
        additionalFiles = @(
            @{ filePath = 'scenario-prompts.md'; content = Get-Content -Raw $promptsPath }
        )
    }
}
Invoke-AgentApi -Method Put -Path '/api/v2/extendedAgent/skills/sqlmi-performance' -Body $sqlMiSkillBody | Out-Null
Write-Ok 'Skill: sqlmi-performance'

Write-Step '[5/8] Uploading implementation knowledge'
if (-not $SkipKnowledgeUpload) {
    foreach ($knowledgeFile in @($guidePath, $promptsPath)) {
        $uploadParameters = @{
            Uri         = "$script:agentEndpoint/api/v1/AgentMemory/upload"
            Headers     = @{ Authorization = "Bearer $(Get-AzureToken 'https://azuresre.dev')" }
            Method      = 'Post'
            Form        = @{ triggerIndexing = 'true'; files = Get-Item $knowledgeFile }
            ErrorAction = 'Stop'
        }
        Invoke-RestMethod @uploadParameters | Out-Null
        Write-Ok "Knowledge: $(Split-Path $knowledgeFile -Leaf)"
    }
}
else {
    Write-Ok 'Knowledge upload skipped by request.'
}

Write-Step '[6/8] Applying the blocking write-approval hook and response plan'
$hookPrompt = @'
Review the proposed response for any Azure, Entra, database, network, security, deployment,
identity, compute, or configuration write. Reads, queries, reports, forecasts, and recommendations
are allowed. If a write is proposed, reject it and list the exact resource, operation, expected
effect, rollback, verification, and risk; require explicit user approval before continuing. Never
approve secret disclosure, evidence deletion, or a scope broader than the approved action.

$ARGUMENTS
'@
$hookBody = @{
    name = 'enterprise-operations-write-approval'
    type = 'GlobalHook'
    properties = @{
        eventType = 'Stop'
        activationMode = 'always'
        description = 'Blocks operational writes until the user explicitly approves the exact scoped action.'
        hook = @{
            type = 'prompt'
            prompt = $hookPrompt
            model = 'ReasoningFast'
            timeout = 30
            failMode = 'Block'
            maxRejections = 3
        }
    }
}
Invoke-AgentApi -Method Put -Path '/api/v2/extendedAgent/hooks/enterprise-operations-write-approval' -Body $hookBody | Out-Null
Write-Ok 'Hook: enterprise-operations-write-approval'

$responsePlan = @{
    id = 'enterprise-operations-incidents'
    name = 'Enterprise Operations Incidents'
    priorities = @('Sev0', 'Sev1', 'Sev2', 'Sev3', 'Sev4')
    titleContains = ''
    handlingAgent = ''
    agentMode = 'review'
}
Invoke-AgentApi -Method Put -Path '/api/v1/incidentPlayground/filters/enterprise-operations-incidents' -Body $responsePlan | Out-Null
Write-Ok 'Response plan: enterprise-operations-incidents [review]'

Write-Step '[7/8] Replacing scheduled operational digests'
if (-not (Test-Path $tasksPath)) { throw "Scheduled-task catalog not found: $tasksPath" }
$taskJson = (Get-Content -Raw $tasksPath).
    Replace('@@SCOPE@@', $Scope).
    Replace('@@SUBSCRIPTION_IDS@@', ($subscriptionIds -join ', '))
$desiredTasks = @($taskJson | ConvertFrom-Json)
$existingTasks = Get-Collection (Invoke-AgentApi -Method Get -Path '/api/v1/scheduledtasks')

foreach ($desiredTask in $desiredTasks) {
    foreach ($existingTask in @($existingTasks | Where-Object { $_.name -eq $desiredTask.name })) {
        if ($existingTask.id) {
            Invoke-AgentApi -Method Delete -Path "/api/v1/scheduledtasks/$($existingTask.id)" | Out-Null
        }
    }
    Invoke-AgentApi -Method Post -Path '/api/v1/scheduledtasks' -Body $desiredTask | Out-Null
    Write-Ok "Scheduled task: $($desiredTask.name) [$($desiredTask.cronExpression) UTC]"
}

Write-Step '[8/8] Verifying configured artifacts'
$skillNames = Get-Collection (Invoke-AgentApi -Method Get -Path '/api/v2/extendedAgent/skills') | ForEach-Object { $_.name }
$hookNames = Get-Collection (Invoke-AgentApi -Method Get -Path '/api/v2/extendedAgent/hooks') | ForEach-Object { $_.name }
$responsePlanNames = Get-Collection (Invoke-AgentApi -Method Get -Path '/api/v1/incidentPlayground/filters') | ForEach-Object { $_.name }
$scheduledTaskNames = Get-Collection (Invoke-AgentApi -Method Get -Path '/api/v1/scheduledtasks') | ForEach-Object { $_.name }
$knowledgeNames = if ($SkipKnowledgeUpload) { @() } else { Get-Collection (Invoke-AgentApi -Method Get -Path '/api/v1/AgentMemory/files') | ForEach-Object { $_.name } }

$requiredTaskNames = @($desiredTasks | ForEach-Object { $_.name })
$missingArtifacts = @()
if ($skillNames -notcontains 'enterprise-operations') { $missingArtifacts += 'skill:enterprise-operations' }
if ($hookNames -notcontains 'enterprise-operations-write-approval') { $missingArtifacts += 'hook:enterprise-operations-write-approval' }
if ($responsePlanNames -notcontains 'Enterprise Operations Incidents' -and $responsePlanNames -notcontains 'enterprise-operations-incidents') { $missingArtifacts += 'response-plan:enterprise-operations-incidents' }
foreach ($taskName in $requiredTaskNames) {
    if ($scheduledTaskNames -notcontains $taskName) { $missingArtifacts += "task:$taskName" }
}

$verification = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    agentId = $agentId
    agentEndpoint = $script:agentEndpoint
    actionIdentityId = $agentIdentityId
    scope = $Scope
    subscriptions = $subscriptionIds
    skills = @($skillNames)
    hooks = @($hookNames)
    responsePlans = @($responsePlanNames)
    scheduledTasks = @($scheduledTaskNames)
    knowledgeFiles = @($knowledgeNames)
    missingArtifacts = @($missingArtifacts)
}
$verification | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding utf8

if ($missingArtifacts.Count -gt 0) {
    throw "Configuration verification failed. Missing: $($missingArtifacts -join ', '). See $reportPath"
}

Write-Ok "Verification report: $reportPath"
Write-Host "`nSRE Agent data-plane configuration completed successfully." -ForegroundColor Green
