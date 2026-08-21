[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [securestring] $AdminPassword,

    [string] $AdminUsername = 'admin',

    [string] $TerraformDirectory = (Join-Path $PSScriptRoot '..\terraform'),

    [string] $DeclarationDirectory = (Join-Path $PSScriptRoot '..\declarations'),

    [string] $DownloadDirectory = (Join-Path $PSScriptRoot '..\.packages'),

    [string] $As3Version = '3.56.0',

    [string] $DoVersion = '1.47.0',

    [string] $TsVersion = '1.41.0',

    [int] $ReadyTimeoutMinutes = 30,

    [switch] $SkipExtensionInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:HttpClient = $null

function Write-Step {
    param([Parameter(Mandatory)][string] $Message)

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

function New-BigIpHttpClient {
    param(
        [Parameter(Mandatory)][string] $Username,
        [Parameter(Mandatory)][securestring] $Password
    )

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.ServerCertificateCustomValidationCallback =
        [System.Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator

    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromMinutes(10)
    $credential = [pscredential]::new($Username, $Password)
    $plainPassword = $credential.GetNetworkCredential().Password
    try {
        $basicToken = [Convert]::ToBase64String(
            [Text.Encoding]::UTF8.GetBytes("${Username}:${plainPassword}")
        )
        $client.DefaultRequestHeaders.Authorization =
            [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Basic', $basicToken)
        $client.DefaultRequestHeaders.Accept.Add(
            [System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new('application/json')
        )
        return $client
    }
    finally {
        $plainPassword = $null
    }
}

function Invoke-BigIpRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PATCH')][string] $Method,
        [Parameter(Mandatory)][string] $Uri,
        [object] $Body,
        [int[]] $AllowedStatusCodes = @(200, 201, 202)
    )

    $delaySeconds = 2
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $request = [System.Net.Http.HttpRequestMessage]::new(
            [System.Net.Http.HttpMethod]::new($Method),
            $Uri
        )
        try {
            if ($null -ne $Body) {
                $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 100 }
                $request.Content = [System.Net.Http.StringContent]::new(
                    $json,
                    [Text.Encoding]::UTF8,
                    'application/json'
                )
            }

            $response = $script:HttpClient.SendAsync($request).GetAwaiter().GetResult()
            try {
                $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $statusCode = [int] $response.StatusCode

                if ($AllowedStatusCodes -contains $statusCode) {
                    if ([string]::IsNullOrWhiteSpace($content)) {
                        return $null
                    }
                    return $content | ConvertFrom-Json -Depth 100
                }

                if (($statusCode -eq 429 -or $statusCode -ge 500) -and $attempt -lt 6) {
                    Write-Warning "BIG-IP returned HTTP $statusCode; retrying in $delaySeconds seconds."
                    Start-Sleep -Seconds $delaySeconds
                    $delaySeconds = [Math]::Min($delaySeconds * 2, 30)
                    continue
                }

                throw "BIG-IP request failed: $Method $Uri returned HTTP $statusCode. $content"
            }
            finally {
                $response.Dispose()
            }
        }
        finally {
            $request.Dispose()
        }
    }
}

function Wait-BigIpReady {
    param(
        [Parameter(Mandatory)][string] $BaseUri,
        [Parameter(Mandatory)][int] $TimeoutMinutes
    )

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    do {
        try {
            Invoke-BigIpRequest -Method GET -Uri "$BaseUri/mgmt/tm/sys/version" | Out-Null
            return
        }
        catch {
            if ((Get-Date) -ge $deadline) {
                throw "BIG-IP did not become ready within $TimeoutMinutes minutes. $($_.Exception.Message)"
            }
            Write-Step 'Waiting for the BIG-IP REST API...'
            Start-Sleep -Seconds 15
        }
    } while ((Get-Date) -lt $deadline)
}

function Get-ExtensionAsset {
    param(
        [Parameter(Mandatory)][string] $Repository,
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][string] $DestinationDirectory
    )

    $releaseUri = "https://api.github.com/repos/F5Networks/$Repository/releases/tags/v$Version"
    $headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'f5-observability-lab' }
    $release = Invoke-RestMethod -Uri $releaseUri -Headers $headers
    $asset = $release.assets |
        Where-Object { $_.name -match '\.noarch\.rpm$' } |
        Select-Object -First 1
    if ($null -eq $asset) {
        throw "Release v$Version in F5Networks/$Repository has no noarch RPM asset."
    }
    $checksumAsset = $release.assets |
        Where-Object { $_.name -eq "$($asset.name).sha256" } |
        Select-Object -First 1
    if ($null -eq $checksumAsset) {
        throw "Release v$Version in F5Networks/$Repository has no SHA-256 asset for $($asset.name)."
    }

    New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
    $destination = Join-Path $DestinationDirectory $asset.name
    $checksumDestination = "$destination.sha256"
    if (-not (Test-Path $destination)) {
        Write-Step "Downloading $($asset.name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $destination
    }
    Invoke-WebRequest `
        -Uri $checksumAsset.browser_download_url `
        -Headers $headers `
        -OutFile $checksumDestination
    $checksumText = Get-Content $checksumDestination -Raw
    if ($checksumText -notmatch '(?i)\b[0-9a-f]{64}\b') {
        throw "Unable to parse the published SHA-256 checksum for $($asset.name)."
    }
    $expectedHash = $Matches[0].ToUpperInvariant()
    $actualHash = (Get-FileHash -Path $destination -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        Remove-Item $destination -Force
        throw "SHA-256 verification failed for $($asset.name); the cached RPM was removed."
    }
    return $destination
}

function Test-ExtensionInstalled {
    param(
        [Parameter(Mandatory)][string] $BaseUri,
        [Parameter(Mandatory)][string] $InfoPath
    )

    try {
        Invoke-BigIpRequest -Method GET -Uri "$BaseUri$InfoPath" | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Wait-PackageTask {
    param(
        [Parameter(Mandatory)][string] $BaseUri,
        [Parameter(Mandatory)][string] $TaskId
    )

    for ($attempt = 1; $attempt -le 120; $attempt++) {
        $task = Invoke-BigIpRequest -Method GET -Uri "$BaseUri/mgmt/shared/iapp/package-management-tasks/$TaskId"
        if ($task.status -eq 'FINISHED') {
            return
        }
        if ($task.status -eq 'FAILED') {
            throw "Extension installation failed: $($task.errorMessage)"
        }
        Start-Sleep -Seconds 5
    }
    throw "Extension installation task $TaskId timed out."
}

function Install-Extension {
    param(
        [Parameter(Mandatory)][string] $BaseUri,
        [Parameter(Mandatory)][string] $RpmPath,
        [Parameter(Mandatory)][string] $InfoPath
    )

    if (Test-ExtensionInstalled -BaseUri $BaseUri -InfoPath $InfoPath) {
        Write-Step "$InfoPath is already available; skipping package installation."
        return
    }

    $fileName = Split-Path $RpmPath -Leaf
    $bytes = [IO.File]::ReadAllBytes($RpmPath)
    $chunkSize = 5MB
    for ($offset = 0; $offset -lt $bytes.Length; $offset += $chunkSize) {
        $length = [Math]::Min($chunkSize, $bytes.Length - $offset)
        $chunk = [byte[]]::new($length)
        [Array]::Copy($bytes, $offset, $chunk, 0, $length)
        $content = [System.Net.Http.ByteArrayContent]::new($chunk)
        $content.Headers.ContentType =
            [System.Net.Http.Headers.MediaTypeHeaderValue]::new('application/octet-stream')
        $content.Headers.Add('Content-Range', "$offset-$($offset + $length - 1)/$($bytes.Length)")
        try {
            $uploadUri = "$BaseUri/mgmt/shared/file-transfer/uploads/$fileName"
            $response = $script:HttpClient.PostAsync($uploadUri, $content).GetAwaiter().GetResult()
            try {
                if (-not $response.IsSuccessStatusCode) {
                    $detail = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    throw "RPM upload failed with HTTP $([int]$response.StatusCode). $detail"
                }
            }
            finally {
                $response.Dispose()
            }
        }
        finally {
            $content.Dispose()
        }
    }

    $task = Invoke-BigIpRequest -Method POST `
        -Uri "$BaseUri/mgmt/shared/iapp/package-management-tasks" `
        -Body @{ operation = 'INSTALL'; packageFilePath = "/var/config/rest/downloads/$fileName" }
    Wait-PackageTask -BaseUri $BaseUri -TaskId $task.id

    for ($attempt = 1; $attempt -le 60; $attempt++) {
        if (Test-ExtensionInstalled -BaseUri $BaseUri -InfoPath $InfoPath) {
            Write-Step "Installed $fileName."
            return
        }
        Start-Sleep -Seconds 5
    }
    throw "$fileName installed, but $InfoPath did not become available."
}

function Wait-DoTask {
    param(
        [Parameter(Mandatory)][string] $BaseUri,
        [Parameter(Mandatory)][string] $TaskId
    )

    for ($attempt = 1; $attempt -le 120; $attempt++) {
        $task = Invoke-BigIpRequest -Method GET `
            -Uri "$BaseUri/mgmt/shared/declarative-onboarding/task/$TaskId"
        $result = @($task) | Select-Object -Last 1
        if ($result.result.status -eq 'OK') {
            return
        }
        if ($result.result.status -eq 'ERROR') {
            throw "Declarative Onboarding failed: $($result.result.message)"
        }
        Start-Sleep -Seconds 5
    }
    throw "Declarative Onboarding task $TaskId timed out."
}

function Invoke-TmshLoggingConfiguration {
    param([Parameter(Mandatory)][string] $BaseUri)

    $commands = @(
        'tmsh modify sys db tmm.tcl.rule.node.allow_loopback_addresses value true',
        'tmsh modify sys syslog remote-servers replace-all-with { telemetry { host 127.0.0.1 remote-port 6514 } }',
        'tmsh modify sys daemon-log-settings mcpd audit enabled',
        'tmsh save sys config'
    )
    foreach ($command in $commands) {
        Invoke-BigIpRequest -Method POST -Uri "$BaseUri/mgmt/tm/util/bash" -Body @{
            command     = 'run'
            utilCmdArgs = "-c '$command'"
        } | Out-Null
    }
}

function Assert-DeclarationResult {
    param(
        [Parameter(Mandatory)][object] $Response,
        [Parameter(Mandatory)][string] $Name
    )

    $errors = @($Response.results) | Where-Object { $_.code -lt 200 -or $_.code -ge 300 }
    if ($errors.Count -gt 0) {
        throw "$Name declaration failed: $($errors | ConvertTo-Json -Depth 20 -Compress)"
    }
}

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw 'Terraform is required to read the applied lab outputs.'
}

$terraformOutputJson = & terraform "-chdir=$TerraformDirectory" output -json
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read Terraform outputs. Apply the approved infrastructure first.'
}
$outputs = $terraformOutputJson | ConvertFrom-Json -Depth 100
$baseUri = "https://$($outputs.bigip_management_public_ip.value):8443"
$workspaceId = $outputs.log_analytics_workspace_customer_id.value
$applicationVip = $outputs.application_vip_private_ip.value
$backendAddresses = @($outputs.backend_private_ips.value)
if ($backendAddresses.Count -ne 2) {
    throw 'Expected exactly two backend private IP addresses from Terraform.'
}

$script:HttpClient = New-BigIpHttpClient -Username $AdminUsername -Password $AdminPassword
try {
    Write-Step "Waiting for BIG-IP at $baseUri..."
    Wait-BigIpReady -BaseUri $baseUri -TimeoutMinutes $ReadyTimeoutMinutes

    if (-not $SkipExtensionInstall -and $PSCmdlet.ShouldProcess($baseUri, 'Install pinned F5 extension packages')) {
        $packages = @(
            @{ Repository = 'f5-declarative-onboarding'; Version = $DoVersion; InfoPath = '/mgmt/shared/declarative-onboarding/info' },
            @{ Repository = 'f5-appsvcs-extension'; Version = $As3Version; InfoPath = '/mgmt/shared/appsvcs/info' },
            @{ Repository = 'f5-telemetry-streaming'; Version = $TsVersion; InfoPath = '/mgmt/shared/telemetry/info' }
        )
        foreach ($package in $packages) {
            $rpm = Get-ExtensionAsset `
                -Repository $package.Repository `
                -Version $package.Version `
                -DestinationDirectory $DownloadDirectory
            Install-Extension -BaseUri $baseUri -RpmPath $rpm -InfoPath $package.InfoPath
        }
    }

    $onboarding = Get-Content (Join-Path $DeclarationDirectory 'onboarding.json') -Raw |
        ConvertFrom-Json -Depth 100
    if ($PSCmdlet.ShouldProcess($baseUri, 'Apply Declarative Onboarding declaration')) {
        Write-Step 'Applying Declarative Onboarding declaration...'
        $doResponse = Invoke-BigIpRequest -Method POST `
            -Uri "$baseUri/mgmt/shared/declarative-onboarding" `
            -Body $onboarding
        $doTask = @($doResponse) | Select-Object -First 1
        Wait-DoTask -BaseUri $baseUri -TaskId $doTask.id
    }

    $telemetry = Get-Content (Join-Path $DeclarationDirectory 'telemetry.json') -Raw |
        ConvertFrom-Json -Depth 100
    $telemetry.Azure_Log_Analytics.workspaceId = $workspaceId
    $telemetry.Azure_Log_Analytics.region = $outputs.location.value

    $as3 = Get-Content (Join-Path $DeclarationDirectory 'as3.json') -Raw |
        ConvertFrom-Json -Depth 100
    $as3.declaration.Lab.Web.serviceMain.virtualAddresses[0] = $applicationVip
    $as3.declaration.Lab.Web.web_pool.members[0].serverAddresses = $backendAddresses
    $as3.declaration.Lab.Web.lab_waf_policy.policy = Get-Content `
        (Join-Path $DeclarationDirectory 'waf-policy.json') -Raw

    if ($PSCmdlet.ShouldProcess($baseUri, 'Apply TS and AS3 declarations and system logging')) {
        Write-Step 'Applying Telemetry Streaming declaration...'
        Invoke-BigIpRequest -Method POST `
            -Uri "$baseUri/mgmt/shared/telemetry/declare" `
            -Body $telemetry | Out-Null

        Write-Step 'Applying AS3 application and logging declaration...'
        $as3Response = Invoke-BigIpRequest -Method POST `
            -Uri "$baseUri/mgmt/shared/appsvcs/declare" `
            -Body $as3
        Assert-DeclarationResult -Response $as3Response -Name 'AS3'

        Write-Step 'Enabling system and audit log forwarding...'
        Invoke-TmshLoggingConfiguration -BaseUri $baseUri
    }

    Write-Step "Configuration complete. Application URL: $($outputs.application_url.value)"
}
finally {
    if ($null -ne $script:HttpClient) {
        $script:HttpClient.Dispose()
    }
}