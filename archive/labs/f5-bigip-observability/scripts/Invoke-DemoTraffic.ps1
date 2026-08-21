[CmdletBinding()]
param(
    [string] $ApplicationUrl,

    [string] $TerraformDirectory = (Join-Path $PSScriptRoot '..\terraform'),

    [ValidateRange(1, 10000)]
    [int] $NormalRequestCount = 25,

    [ValidateRange(1, 100)]
    [int] $AttackRounds = 3,

    [ValidateRange(0, 10000)]
    [int] $DelayMilliseconds = 200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ApplicationUrl)) {
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        throw 'Provide -ApplicationUrl or install Terraform so the script can read outputs.'
    }
    $terraformOutputJson = & terraform "-chdir=$TerraformDirectory" output -json
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read Terraform outputs. Provide -ApplicationUrl explicitly.'
    }
    $outputs = $terraformOutputJson | ConvertFrom-Json -Depth 100
    $ApplicationUrl = $outputs.application_url.value
}

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(15)
try {
    $results = [Collections.Generic.List[object]]::new()
    for ($requestNumber = 1; $requestNumber -le $NormalRequestCount; $requestNumber++) {
        $uri = "$($ApplicationUrl.TrimEnd('/'))/?request=$requestNumber"
        $response = $client.GetAsync($uri).GetAwaiter().GetResult()
        try {
            $results.Add([pscustomobject]@{
                Type       = 'normal'
                Uri        = $uri
                StatusCode = [int] $response.StatusCode
            })
        }
        finally {
            $response.Dispose()
        }
        if ($DelayMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    $attackPaths = @(
        '/?id=1%20OR%201%3D1--',
        '/?q=%3Cscript%3Ealert%281%29%3C%2Fscript%3E',
        '/..%2F..%2F..%2F..%2Fetc%2Fpasswd',
        '/?cmd=%3Bcat%20%2Fetc%2Fpasswd'
    )
    for ($round = 1; $round -le $AttackRounds; $round++) {
        foreach ($path in $attackPaths) {
            $uri = "$($ApplicationUrl.TrimEnd('/'))$path"
            $response = $client.GetAsync($uri).GetAwaiter().GetResult()
            try {
                $results.Add([pscustomobject]@{
                    Type       = 'waf-test'
                    Uri        = $uri
                    StatusCode = [int] $response.StatusCode
                })
            }
            finally {
                $response.Dispose()
            }
            if ($DelayMilliseconds -gt 0) {
                Start-Sleep -Milliseconds $DelayMilliseconds
            }
        }
    }

    $results | Format-Table Type, StatusCode, Uri -AutoSize
    $blocked = @($results | Where-Object { $_.Type -eq 'waf-test' -and $_.StatusCode -eq 403 }).Count
    Write-Host "Sent $($results.Count) requests. WAF returned HTTP 403 for $blocked test requests."
}
finally {
    $client.Dispose()
}