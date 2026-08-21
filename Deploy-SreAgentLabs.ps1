#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Alias('UseCases')]
    [string]$Scenarios,
    [string]$SubscriptionId,
    [string[]]$TargetSubscriptionIds,
    [string]$Location = 'eastus2',
    [ValidatePattern('^[a-z0-9-]{2,24}$')]
    [string]$EnvironmentPrefix = 'srelab',
    [ValidateSet('Anthropic', 'MicrosoftFoundry')]
    [string]$ModelProvider = 'Anthropic',
    [ValidateSet('Stop', 'Continue')]
    [string]$OnError = 'Stop',
    [switch]$PlanOnly,
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'deployment/scenarios.json'
$manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json

function Write-Section([string]$Title) {
    Write-Host "`n== $Title ==" -ForegroundColor Cyan
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory)] [string]$Command,
        [Parameter(Mandatory)] [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        $displayArguments = @($Arguments)
        if ($Arguments.Count -ge 4 -and $Arguments[0] -eq 'env' -and $Arguments[1] -eq 'set' -and $Arguments[2] -match 'PASSWORD|PAT|SECRET|TOKEN') {
            $displayArguments[3] = '<redacted>'
        }
        throw "Command failed ($LASTEXITCODE): $Command $($displayArguments -join ' ')"
    }
}

function New-LabPassword {
    $bytes = [byte[]]::new(24)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return 'Az9!' + [Convert]::ToBase64String($bytes).Replace('+', 'A').Replace('/', 'z').Replace('=', '7')
}

function Resolve-ScenarioSelection {
    param([string]$Selection)

    if ([string]::IsNullOrWhiteSpace($Selection)) {
        Write-Section 'Available scenarios'
        $manifest.scenarios | ForEach-Object {
            $status = if ($_.readiness -eq 'guided') { 'guided setup' } else { 'deployable' }
            Write-Host ("{0,2}. {1} [{2}]" -f $_.number, $_.name, $status)
        }
        $Selection = Read-Host "Enter 'all' or comma-separated scenario numbers (for example 2,4,7,10)"
    }

    if ($Selection.Trim() -ieq 'all') {
        return @($manifest.scenarios)
    }

    $numbers = @($Selection -split ',' | ForEach-Object {
        $value = $_.Trim()
        if ($value -notmatch '^\d+$') { throw "Invalid scenario '$value'. Use 'all' or comma-separated numbers from 1 to 13." }
        [int]$value
    } | Select-Object -Unique)

    if ($numbers.Count -eq 0) { throw 'Select at least one scenario.' }
    $invalid = @($numbers | Where-Object { $_ -lt 1 -or $_ -gt 13 })
    if ($invalid.Count -gt 0) { throw "Unknown scenario number(s): $($invalid -join ', '). Valid values are 1 to 13." }

    return @($manifest.scenarios | Where-Object { $_.number -in $numbers } | Sort-Object number)
}

function Get-DeploymentPlan {
    param([object[]]$SelectedScenarios)

    $selectedLabIds = @($SelectedScenarios.lab | Select-Object -Unique)
    $dependencies = @($manifest.labs | Where-Object { $_.id -in $selectedLabIds } | ForEach-Object {
        if ($_.PSObject.Properties.Name -contains 'dependsOn') { $_.dependsOn }
    } | Where-Object { $_ })
    $selectedLabIds = @($selectedLabIds + $dependencies | Select-Object -Unique)
    $labs = @($manifest.labs | Where-Object { $_.id -in $selectedLabIds })
    [pscustomobject]@{
        Scenarios = $SelectedScenarios
        DeployableLabs = @($labs | Where-Object { $_.azdCommand })
        GuidedLabs = @($labs | Where-Object { -not $_.azdCommand })
    }
}

function Show-DeploymentPlan {
    param([pscustomobject]$Plan)

    Write-Section 'Selected use cases'
    $Plan.Scenarios | ForEach-Object {
        Write-Host ("{0,2}. {1} -> {2} ({3})" -f $_.number, $_.name, $_.lab, $_.readiness)
    }

    Write-Section 'Unique lab packages'
    $Plan.DeployableLabs | ForEach-Object {
        Write-Host "DEPLOY  $($_.id)"
        Write-Host "        $($_.warning)" -ForegroundColor Yellow
    }
    $Plan.GuidedLabs | ForEach-Object {
        Write-Host "GUIDED  $($_.id)"
        Write-Host "        $($_.warning)" -ForegroundColor Yellow
    }

    if ($Plan.Scenarios.number -contains 13) {
        Write-Host 'Scenario 13 scope: multiple subscriptions in the same Microsoft Entra tenant only.' -ForegroundColor Yellow
    }
}

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Get-AzureContext {
    Assert-Command 'az'
    Assert-Command 'azd'

    $accountJson = & az account show --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $accountJson) { throw "Azure CLI is not signed in. Run 'az login' and try again." }
    $account = $accountJson | ConvertFrom-Json
    $primarySubscription = if ($SubscriptionId) { $SubscriptionId } else { $account.id }

    $subscriptionJson = & az account show --subscription $primarySubscription --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $subscriptionJson) { throw "Subscription '$primarySubscription' is not available to the signed-in account." }
    $primary = $subscriptionJson | ConvertFrom-Json

    $targets = @($TargetSubscriptionIds | Where-Object { $_ } | Select-Object -Unique)
    if ($targets.Count -eq 0) { $targets = @($primary.id) }
    foreach ($targetId in $targets) {
        $targetJson = & az account show --subscription $targetId --output json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $targetJson) { throw "Target subscription '$targetId' is not available to the signed-in account." }
        $target = $targetJson | ConvertFrom-Json
        if ($target.tenantId -ne $primary.tenantId) {
            throw "Target subscription '$targetId' belongs to tenant '$($target.tenantId)', not active tenant '$($primary.tenantId)'. Scenario 13 supports same-tenant subscriptions only."
        }
    }

    [pscustomobject]@{ SubscriptionId = $primary.id; SubscriptionName = $primary.name; TenantId = $primary.tenantId; Targets = $targets }
}

function Initialize-AzdEnvironment {
    param([object]$Lab, [pscustomobject]$AzureContext)

    $environmentName = "$EnvironmentPrefix-$($Lab.id)"
    Push-Location (Join-Path $repoRoot $Lab.path)
    try {
        & azd env select $environmentName 2>$null
        if ($LASTEXITCODE -ne 0) { Invoke-CheckedCommand 'azd' @('env', 'new', $environmentName, '--no-prompt') }

        Invoke-CheckedCommand 'azd' @('env', 'set', 'AZURE_SUBSCRIPTION_ID', $AzureContext.SubscriptionId)
        Invoke-CheckedCommand 'azd' @('env', 'set', 'AZURE_LOCATION', $Location)

        $principalId = (& az ad signed-in-user show --query id --output tsv 2>$null)
        if ($LASTEXITCODE -eq 0 -and $principalId) {
            Invoke-CheckedCommand 'azd' @('env', 'set', 'AZURE_PRINCIPAL_ID', $principalId.Trim())
        }

        if ($Lab.id -in @('vm-cosmosdb', 'public-port-guard')) {
            Invoke-CheckedCommand 'azd' @('env', 'set', 'VM_ADMIN_PASSWORD', (New-LabPassword))
        }
        if ($Lab.id -eq 'zava-learning') {
            Invoke-CheckedCommand 'azd' @('env', 'set', 'POSTGRES_ADMIN_PASSWORD', (New-LabPassword))
            Invoke-CheckedCommand 'azd' @('env', 'set', 'POSTGRES_POOL_PASSWORD', (New-LabPassword))
            Invoke-CheckedCommand 'azd' @('env', 'set', 'VM_ADMIN_PASSWORD', (New-LabPassword))
            $deployerIp = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 15).Trim()
            Invoke-CheckedCommand 'azd' @('env', 'set', 'DEPLOYER_IP', $deployerIp)
        }
    }
    finally {
        Pop-Location
    }

    return $environmentName
}

function Invoke-LabDeployment {
    param([object]$Lab, [pscustomobject]$AzureContext)

    $environmentName = Initialize-AzdEnvironment -Lab $Lab -AzureContext $AzureContext
    Push-Location (Join-Path $repoRoot $Lab.path)
    try {
        Write-Section "Deploying $($Lab.id)"
        Invoke-CheckedCommand 'az' @('account', 'set', '--subscription', $AzureContext.SubscriptionId)
        Invoke-CheckedCommand 'azd' @($Lab.azdCommand, '--environment', $environmentName, '--no-prompt')

        if ($Lab.postDeploy -like 'bash:*') {
            Assert-Command 'bash'
            Invoke-CheckedCommand 'bash' @(($Lab.postDeploy -split ':', 2)[1])
        }
        elseif ($Lab.postDeploy -like 'pwsh:*') {
            Invoke-CheckedCommand 'pwsh' @('-NoProfile', '-File', ($Lab.postDeploy -split ':', 2)[1])
        }
        elseif ($Lab.postDeploy -eq 'zava') {
            $resourceGroup = "rg-zava-learning-$environmentName"
            Invoke-CheckedCommand 'pwsh' @('-NoProfile', '-File', 'scripts/post-provision.ps1', '-ResourceGroup', $resourceGroup)
            Invoke-CheckedCommand 'pwsh' @('-NoProfile', '-File', 'scripts/deploy-sre-agent.ps1', '-ResourceGroup', $resourceGroup, '-ModelProvider', $ModelProvider)
            Write-Host 'Complete the checked-in SRE Agent configuration using the portal steps in labs/zava-learning/README.md.' -ForegroundColor Yellow
        }
    }
    finally {
        Pop-Location
    }
}

$selectedScenarios = Resolve-ScenarioSelection -Selection $Scenarios
$plan = Get-DeploymentPlan -SelectedScenarios $selectedScenarios
Show-DeploymentPlan -Plan $plan

if ($PlanOnly) {
    Write-Host "`nPlan only: no Azure resources were changed." -ForegroundColor Green
    return
}

if ($plan.Scenarios.number -contains 13 -and (-not $TargetSubscriptionIds -or $TargetSubscriptionIds.Count -lt 2)) {
    $rawTargets = Read-Host 'Scenario 13 requires at least two same-tenant subscription IDs (comma-separated)'
    $TargetSubscriptionIds = @($rawTargets -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($TargetSubscriptionIds.Count -lt 2) { throw 'Scenario 13 requires at least two target subscription IDs.' }
}

$azureContext = Get-AzureContext
Write-Section 'Azure target'
Write-Host "Subscription: $($azureContext.SubscriptionName) ($($azureContext.SubscriptionId))"
Write-Host "Tenant:       $($azureContext.TenantId)"
if ($plan.Scenarios.number -contains 13) { Write-Host "Health scope: $($azureContext.Targets -join ', ')" }

if (-not $Yes) {
    $confirmation = Read-Host "Type DEPLOY to provision the listed resources"
    if ($confirmation -cne 'DEPLOY') { Write-Host 'Deployment cancelled. No Azure resources were changed.'; return }
}

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($lab in $plan.DeployableLabs) {
    if (-not $PSCmdlet.ShouldProcess("$($azureContext.SubscriptionName)/$($lab.id)", 'Deploy Azure lab')) { continue }
    try {
        Invoke-LabDeployment -Lab $lab -AzureContext $azureContext
    }
    catch {
        $failures.Add("$($lab.id): $($_.Exception.Message)")
        Write-Error -ErrorAction Continue "Deployment failed for $($lab.id): $($_.Exception.Message)"
        if ($OnError -eq 'Stop') { break }
    }
}

if ($plan.GuidedLabs.Count -gt 0) {
    Write-Section 'Guided enterprise steps'
    Write-Host 'Continue with labs/enterprise-operations/infra/README.md after the base Zava workload exists.'
    if ($plan.Scenarios.number -contains 13) {
        Write-Host "Use direct RBAC for these same-tenant subscriptions: $($azureContext.Targets -join ', ')"
    }
}

Write-Section 'Deployment summary'
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAILED  $_" -ForegroundColor Red }
    throw "$($failures.Count) lab deployment(s) failed."
}
Write-Host 'All automated lab deployments completed. Review any guided enterprise steps above.' -ForegroundColor Green