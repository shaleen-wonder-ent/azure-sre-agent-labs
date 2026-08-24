[CmdletBinding()]
param(
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot "..\infra"),
    [string]$AgentEndpoint
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$labRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$skillPath = Join-Path $labRoot "sre-config\skills\entra-authentication\SKILL.md"
$fixturePath = Join-Path $labRoot "docs\entra-signin-fixture.json"

foreach ($path in @($skillPath, $fixturePath)) {
    if (-not (Test-Path $path)) { throw "Required file not found: $path" }
}

function Get-AzureToken([string]$Resource) {
    $token = az account get-access-token --resource $Resource --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $token) {
        throw "Could not obtain an Azure token for $Resource. Run 'az login' first."
    }
    return $token
}

if (-not $AgentEndpoint) {
    Push-Location (Resolve-Path $TerraformDirectory).Path
    try {
        $outputs = terraform output -json | ConvertFrom-Json
    }
    finally {
        Pop-Location
    }
    $AgentEndpoint = [string]$outputs.sre_agent_endpoint.value
}
if (-not $AgentEndpoint) { throw "SRE Agent endpoint could not be resolved." }
$AgentEndpoint = $AgentEndpoint.TrimEnd("/")

$skillBody = @{
    name       = "entra-authentication"
    type       = "Skill"
    properties = @{
        description     = "Entra sign-in and authentication troubleshooting: aggregate failures, classify the failing stage, correlate identity changes, and redact sensitive data."
        tools           = @("SearchMemory", "QueryLogAnalyticsByWorkspaceId", "RunAzCliReadCommands", "GetAzCliHelp")
        skillContent    = Get-Content -Raw $skillPath
        additionalFiles = @(
            @{ filePath = "entra-signin-fixture.json"; content = Get-Content -Raw $fixturePath }
        )
    }
} | ConvertTo-Json -Depth 12

$headers = @{ Authorization = "Bearer $(Get-AzureToken 'https://azuresre.dev')" }
Invoke-RestMethod -Method Put -Uri "$AgentEndpoint/api/v2/extendedAgent/skills/entra-authentication" `
    -Headers $headers -ContentType "application/json" -Body $skillBody | Out-Null

$skills = Invoke-RestMethod -Method Get -Uri "$AgentEndpoint/api/v2/extendedAgent/skills" -Headers $headers
$names = if ($skills.PSObject.Properties.Name -contains "value") { $skills.value.name } else { $skills.name }
Write-Host "Installed skills: $($names -join ', ')"
if ($names -contains "entra-authentication") {
    Write-Host "entra-authentication skill is installed and carries entra-signin-fixture.json."
}
else {
    throw "entra-authentication skill did not appear after upload."
}
