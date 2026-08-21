[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [securestring] $AdminPassword,

    [string] $AdminUsername = 'admin',

    [string] $TerraformDirectory = (Join-Path $PSScriptRoot '..\terraform'),

    [ValidateRange(60, 900)]
    [int] $ObservationSeconds = 75,

    [ValidateRange(1, 1000)]
    [int] $RequestCount = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw 'Terraform is required to read the applied lab outputs.'
}

$terraformOutputJson = & terraform "-chdir=$TerraformDirectory" output -json
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read Terraform outputs.'
}
$outputs = $terraformOutputJson | ConvertFrom-Json -Depth 100
$managementUri = "https://$($outputs.bigip_management_public_ip.value):8443"
$applicationUrl = $outputs.application_url.value
$memberAddress = @($outputs.backend_private_ips.value)[0]
$memberPath = "~Lab~Web~${memberAddress}:80"
$memberUri = "$managementUri/mgmt/tm/ltm/pool/~Lab~Web~web_pool/members/$memberPath"
$credential = [pscredential]::new($AdminUsername, $AdminPassword)

function Set-PoolMemberSession {
    param([Parameter(Mandatory)][ValidateSet('user-disabled', 'user-enabled')][string] $Session)

    Invoke-RestMethod -Method Patch `
        -Uri $memberUri `
        -Authentication Basic `
        -Credential $credential `
        -SkipCertificateCheck `
        -ContentType 'application/json' `
        -Body (@{ session = $Session } | ConvertTo-Json) | Out-Null
}

if (-not $PSCmdlet.ShouldProcess("$memberAddress`:80", "Disable for $ObservationSeconds seconds")) {
    return
}

$disabled = $false
try {
    Write-Host "Disabling pool member $memberAddress`:80..."
    Set-PoolMemberSession -Session user-disabled
    $disabled = $true

    $deadline = (Get-Date).AddSeconds($ObservationSeconds)
    $client = [System.Net.Http.HttpClient]::new()
    try {
        for ($requestNumber = 1; $requestNumber -le $RequestCount; $requestNumber++) {
            $uri = "$($applicationUrl.TrimEnd('/'))/?failure-test=$requestNumber"
            $response = $client.GetAsync($uri).GetAwaiter().GetResult()
            $response.Dispose()
        }
    }
    finally {
        $client.Dispose()
    }

    $remainingSeconds = [Math]::Ceiling(($deadline - (Get-Date)).TotalSeconds)
    if ($remainingSeconds -gt 0) {
        Write-Host "Holding the failure state for $remainingSeconds seconds so the system poller observes it..."
        Start-Sleep -Seconds $remainingSeconds
    }
}
finally {
    if ($disabled) {
        Write-Host "Re-enabling pool member $memberAddress`:80..."
        Set-PoolMemberSession -Session user-enabled
    }
}

Write-Host 'Pool failure simulation completed and the member was restored.'