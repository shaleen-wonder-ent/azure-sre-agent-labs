$repoRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $repoRoot 'Deploy-SreAgentLabs.ps1'

Describe 'Deploy-SreAgentLabs plan-only mode' {
    It 'deduplicates scenarios into canonical lab packages' {
        $output = & pwsh -NoProfile -File $launcher -Scenarios '2,4,7,10,13' -PlanOnly | Out-String

        $output | Should Match 'DEPLOY  zava-learning'
        $output | Should Match 'DEPLOY  deployment-compliance'
        $output | Should Match 'GUIDED  enterprise-operations'
        [regex]::Matches($output, '(?m)^DEPLOY  deployment-compliance\r?$').Count | Should Be 1
    }

    It 'maps all scenarios to five deployable labs and one guided overlay' {
        $output = & pwsh -NoProfile -File $launcher -Scenarios all -PlanOnly | Out-String

        [regex]::Matches($output, '(?m)^DEPLOY  ').Count | Should Be 5
        [regex]::Matches($output, '(?m)^GUIDED  ').Count | Should Be 1
        $output | Should Match 'same Microsoft Entra tenant only'
    }

    It 'includes the required Zava base for an enterprise-only selection' {
        $output = & pwsh -NoProfile -File $launcher -Scenarios '13' -PlanOnly | Out-String

        $output | Should Match 'DEPLOY  zava-learning'
        $output | Should Match 'GUIDED  enterprise-operations'
    }

    It 'rejects scenario numbers outside the catalog' {
        & pwsh -NoProfile -File $launcher -Scenarios '2,14' -PlanOnly *> $null

        $LASTEXITCODE | Should Not Be 0
    }
}