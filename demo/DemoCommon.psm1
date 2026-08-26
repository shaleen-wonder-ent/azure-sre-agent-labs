<#
.SYNOPSIS
  Shared helpers for the per-use-case demo warm-up scripts (demo/Warmup-UC*.ps1).

  These functions keep every warm-up script consistent: prerequisite checks,
  Git Bash discovery, resource-group verification, and copy-paste prompt output.
  The scripts are thin wrappers around the proven per-lab break-*/Seed-*/configure-*
  scripts described in SRE-AGENT-DEMO-RUNBOOK.md.
#>

Set-StrictMode -Version Latest

function Get-DemoRepoRoot {
    # This module lives in <repo>/demo, so the repo root is one level up.
    return (Split-Path -Parent $PSScriptRoot)
}

function Write-DemoBanner {
    param(
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Agent
    )
    Write-Host ''
    Write-Host '==================================================================' -ForegroundColor Cyan
    Write-Host ("  UC{0:D2} — {1}" -f $Number, $Title) -ForegroundColor Cyan
    Write-Host ("  Agent / target: {0}" -f $Agent) -ForegroundColor DarkCyan
    Write-Host '==================================================================' -ForegroundColor Cyan
}

function Write-DemoStep {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "-> $Message" -ForegroundColor Gray
}

function Write-DemoInfo {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "   $Message" -ForegroundColor DarkGray
}

function Write-DemoWarn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "!  $Message" -ForegroundColor Yellow
}

function Write-DemoPrompt {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ''
    Write-Host 'Paste this into the SRE Agent (start a NEW thread):' -ForegroundColor Green
    Write-Host '------------------------------------------------------------------' -ForegroundColor DarkGreen
    Write-Host $Text -ForegroundColor White
    Write-Host '------------------------------------------------------------------' -ForegroundColor DarkGreen
}

function Write-DemoHighlight {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ''
    Write-Host "Highlight to record: $Text" -ForegroundColor Magenta
}

function Write-DemoReset {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ''
    Write-Host "Reset after recording: $Text" -ForegroundColor DarkYellow
}

function Assert-DemoTool {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' was not found in PATH. See demo/README.md for prerequisites."
    }
}

function Test-DemoPrereq {
    <#
      Verifies the tools each demo needs and that Azure CLI is signed in.
      Pass -RequireBash for demos whose underlying script is bash (starter-lab, vm-cosmosdb).
      Returns nothing; throws on hard failures, warns on soft ones.
    #>
    param(
        [string[]]$Tools = @('az', 'azd'),
        [switch]$RequireBash,
        [switch]$Quiet
    )

    foreach ($tool in $Tools) { Assert-DemoTool -Name $tool }
    if ($RequireBash) { [void](Get-DemoBashPath) }

    $account = & az account show --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $account) {
        throw "Azure CLI is not signed in. Run 'az login' (and 'az account set --subscription <id>') first."
    }
    if (-not $Quiet) {
        $ctx = $account | ConvertFrom-Json
        Write-DemoInfo "Azure context: $($ctx.name) ($($ctx.id))"
    }
}

function Get-DemoBashPath {
    <# Locates a usable bash. On Windows this prefers Git Bash. #>
    if (-not $IsWindows) {
        Assert-DemoTool 'bash'
        return 'bash'
    }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git/bin/bash.exe'),
        (Join-Path $env:ProgramFiles 'Git/usr/bin/bash.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git/bin/bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs/Git/bin/bash.exe')
    )
    $gitBash = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if (-not $gitBash) {
        throw "Git Bash was not found. Install Git for Windows with 'winget install Git.Git'."
    }
    return $gitBash
}

function Invoke-DemoBash {
    <#
      Runs a bash script inside a lab directory. On Windows this strips the
      WindowsApps stub directory from PATH so the real tools resolve, matching
      the behaviour of Deploy-SreAgentLabs.ps1.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$ScriptRelativePath,
        [string[]]$Arguments = @()
    )
    $bash = Get-DemoBashPath
    Push-Location $WorkingDirectory
    $originalPath = $env:PATH
    try {
        if ($IsWindows) {
            $env:PATH = (($env:PATH -split ';') | Where-Object { $_ -notmatch '\\WindowsApps(?:\\|$)' }) -join ';'
        }
        & $bash $ScriptRelativePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "bash $ScriptRelativePath exited with code $LASTEXITCODE."
        }
    }
    finally {
        $env:PATH = $originalPath
        Pop-Location
    }
}

function Invoke-DemoPwsh {
    <# Runs a PowerShell script inside a lab directory and checks the exit code. #>
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$ScriptRelativePath,
        [string[]]$Arguments = @()
    )
    Push-Location $WorkingDirectory
    try {
        & pwsh -NoProfile -File $ScriptRelativePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "pwsh $ScriptRelativePath exited with code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function Test-DemoResourceGroup {
    <# Best-effort check that a lab is deployed. Warns (does not throw) if missing. #>
    param(
        [Parameter(Mandatory)][string]$ResourceGroup,
        [string]$SubscriptionId
    )
    $azParams = @('group', 'show', '--name', $ResourceGroup, '--output', 'none')
    if ($SubscriptionId) { $azParams += @('--subscription', $SubscriptionId) }
    & az @azParams 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-DemoWarn "Resource group '$ResourceGroup' was not found. Deploy the lab first (see Deploy-SreAgentLabs.ps1), or pass -ResourceGroup."
        return $false
    }
    Write-DemoInfo "Verified resource group '$ResourceGroup'."
    return $true
}

function Set-DemoSubscription {
    param([string]$SubscriptionId)
    if (-not $SubscriptionId) { return }
    & az account set --subscription $SubscriptionId 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not select subscription '$SubscriptionId'. Check the id and your access."
    }
}

function Wait-DemoIngestion {
    <# Waits for Activity Log ingestion before the presenter pastes the prompt. #>
    param([int]$Seconds = 120)
    if ($Seconds -le 0) { return }
    Write-DemoStep "Waiting ${Seconds}s for Activity Log ingestion before you paste the prompt..."
    Start-Sleep -Seconds $Seconds
}

Export-ModuleMember -Function `
    Get-DemoRepoRoot, Write-DemoBanner, Write-DemoStep, Write-DemoInfo, Write-DemoWarn, `
    Write-DemoPrompt, Write-DemoHighlight, Write-DemoReset, Assert-DemoTool, Test-DemoPrereq, `
    Get-DemoBashPath, Invoke-DemoBash, Invoke-DemoPwsh, Test-DemoResourceGroup, `
    Set-DemoSubscription, Wait-DemoIngestion
