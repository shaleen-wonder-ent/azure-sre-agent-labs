[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SkillName,
    [Parameter(Mandatory)][string]$SkillPath,
    [string]$FixturePath,
    [string]$Description,
    [string[]]$Tools = @("SearchMemory", "QueryLogAnalyticsByWorkspaceId", "RunAzCliReadCommands", "GetAzCliHelp"),
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot "..\infra"),
    [string]$AgentEndpoint
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path $SkillPath)) { throw "Skill file not found: $SkillPath" }
if ($FixturePath -and -not (Test-Path $FixturePath)) { throw "Fixture file not found: $FixturePath" }

function Get-AzureToken([string]$Resource) {
    $token = az account get-access-token --resource $Resource --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $token) {
        throw "Could not obtain an Azure token for $Resource. Run 'az login' first."
    }
    return $token
}

if (-not $AgentEndpoint) {
    Push-Location (Resolve-Path $TerraformDirectory).Path
    try { $outputs = terraform output -json | ConvertFrom-Json } finally { Pop-Location }
    $AgentEndpoint = [string]$outputs.sre_agent_endpoint.value
}
if (-not $AgentEndpoint) { throw "SRE Agent endpoint could not be resolved." }
$AgentEndpoint = $AgentEndpoint.TrimEnd("/")

if (-not $Description) { $Description = "Enterprise operations skill: $SkillName." }

$properties = @{
    description  = $Description
    tools        = $Tools
    skillContent = Get-Content -Raw $SkillPath
}
if ($FixturePath) {
    $properties.additionalFiles = @(
        @{ filePath = (Split-Path $FixturePath -Leaf); content = Get-Content -Raw $FixturePath }
    )
}

$skillBody = @{ name = $SkillName; type = "Skill"; properties = $properties } | ConvertTo-Json -Depth 12
$headers = @{ Authorization = "Bearer $(Get-AzureToken 'https://azuresre.dev')" }

Invoke-RestMethod -Method Put -Uri "$AgentEndpoint/api/v2/extendedAgent/skills/$SkillName" `
    -Headers $headers -ContentType "application/json" -Body $skillBody | Out-Null

$skills = Invoke-RestMethod -Method Get -Uri "$AgentEndpoint/api/v2/extendedAgent/skills" -Headers $headers
$names = if ($skills.PSObject.Properties.Name -contains "value") { $skills.value.name } else { $skills.name }
Write-Host "Installed skills: $($names -join ', ')"
if ($names -notcontains $SkillName) { throw "$SkillName did not appear after upload." }
Write-Host "$SkillName is installed$(if ($FixturePath) { ' and carries ' + (Split-Path $FixturePath -Leaf) })."
