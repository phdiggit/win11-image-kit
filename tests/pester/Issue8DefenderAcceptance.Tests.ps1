$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Issue 8 Defender exclusion acceptance guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Set-KitDefenderExclusionState.ps1")

        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-issue8-acceptance-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
        $script:PathMap = @{
            WorkRoot = Join-Path $script:TempRoot "work"
            DeployRoot = Join-Path $script:TempRoot "deploy"
            PackageRoot = Join-Path $script:TempRoot "packages"
            ConfigRoot = Join-Path $script:TempRoot "configs"
            ToolRoot = Join-Path $script:TempRoot "tools"
            DataRoot = Join-Path $script:TempRoot "data"
        }
        $script:AllowedPath = [pscustomobject]@{
            id = "cache"
            type = "path"
            value = '${WorkRoot}\cache'
            scope = "kit-cache"
            reason = "cache"
            required = $false
            failurePolicy = "manual"
        }
        $script:BlockedDriveRoot = [pscustomobject]@{
            id = "drive-root"
            type = "path"
            value = [IO.Path]::GetPathRoot($env:SystemRoot)
            scope = "drive-root"
            reason = "blocked"
            required = $true
            failurePolicy = "fail"
        }
        $script:BlockedProcess = [pscustomobject]@{
            id = "generic-process"
            type = "process"
            value = (Join-Path $script:PathMap.ToolRoot "powershell.exe")
            scope = "generic-process"
            reason = "blocked"
            required = $false
            failurePolicy = "manual"
        }
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "documents the acceptance scope, non-goals, matrix, and manual checklist" {
        $docPath = Join-Path $script:RepoRoot "docs\17-issue8-defender-exclusion-acceptance.md"
        $content = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8

        Assert-KitMatch $content "Status: accepted-pending-manual-closure"
        Assert-KitMatch $content "## Scope"
        Assert-KitMatch $content "## Non-goals"
        Assert-KitMatch $content "## Acceptance Matrix"
        Assert-KitMatch $content "## Manual Checklist"
        Assert-KitMatch $content "16-issue8-defender-exclusion-policy.md"
        Assert-KitMatch $content "18-issue8-close-preparation.md"
        Assert-KitMatch $content "19-issue8-main-validation-evidence.md"
    }

    It "keeps docs and README linked to the acceptance layer" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $policyDoc = Get-Content -LiteralPath (Join-Path $script:RepoRoot "docs\16-issue8-defender-exclusion-policy.md") -Raw -Encoding UTF8

        Assert-KitMatch $readme "17-issue8-defender-exclusion-acceptance.md"
        Assert-KitMatch $policyDoc "17-issue8-defender-exclusion-acceptance.md"
    }

    It "keeps the manifest and schema limited to explicit path/process exclusions" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\defender-exclusions.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $schema = Get-Content -LiteralPath (Join-Path $script:RepoRoot "schemas\defender-exclusions.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "exclusions") $true
        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "paths") $false
        Assert-KitEqual ($manifest.PSObject.Properties.Name -contains "processes") $false
        Assert-KitEqual ($schema.properties.exclusions.items.properties.type.enum -contains "path") $true
        Assert-KitEqual ($schema.properties.exclusions.items.properties.type.enum -contains "process") $true
        Assert-KitEqual ($schema.properties.exclusions.items.properties.type.enum -contains "extension") $false
        Assert-KitEqual ([bool]$schema.properties.exclusions.items.additionalProperties) $false
        Assert-KitEqual ([bool]$schema.additionalProperties) $false

        foreach ($item in @($manifest.exclusions)) {
            Assert-KitNotNullOrEmpty $item.scope
            Assert-KitNotNullOrEmpty $item.reason
        }
    }

    It "does not add active code paths that disable Defender protections" {
        $relativePaths = @(
            "scripts\common\Get-KitDefenderExclusionState.ps1",
            "scripts\common\Set-KitDefenderExclusionState.ps1",
            "scripts\common\Test-KitDefenderExclusionPolicy.ps1",
            "scripts\postdeploy\Set-DefenderExclusions.ps1"
        )
        $content = ($relativePaths | ForEach-Object {
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $_) -Raw -Encoding UTF8
        }) -join "`n"

        foreach ($pattern in @(
            "Set-MpPreference\s+.*-DisableRealtimeMonitoring",
            "Set-MpPreference\s+.*-DisableBehaviorMonitoring",
            "Set-MpPreference\s+.*-DisableIOAVProtection",
            "Set-MpPreference\s+.*-DisableBlockAtFirstSeen",
            "Set-MpPreference\s+.*-DisableScriptScanning",
            "Set-MpPreference\s+.*-DisableArchiveScanning",
            "Set-MpPreference\s+.*-MAPSReporting",
            "Set-MpPreference\s+.*-SubmitSamplesConsent",
            "Set-MpPreference\s+.*-PUAProtection\s+0"
        )) {
            Assert-KitNotMatch $content $pattern
        }

        Assert-KitMatch $content "Add-MpPreference\s+-ExclusionPath"
        Assert-KitMatch $content "Add-MpPreference\s+-ExclusionProcess"
        Assert-KitMatch $content "Get-MpPreference"
    }

    It "keeps WhatIf plan-only by avoiding Defender query and mutation seams" {
        $script:QueryCount = 0
        $script:MutationCount = 0
        $query = {
            $script:QueryCount++
            throw "query must not run"
        }
        $mutation = {
            param([string]$Type, [string]$Value)
            $script:MutationCount++
            throw "mutation must not run"
        }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($script:AllowedPath) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation -WhatIf)[0]

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.action "would-add"
        Assert-KitEqual $script:QueryCount 0
        Assert-KitEqual $script:MutationCount 0
    }

    It "does not call mutation for blocked path or generic process policy results" {
        $script:QueryCount = 0
        $script:MutationCount = 0
        $query = {
            $script:QueryCount++
            throw "query must not run"
        }
        $mutation = {
            param([string]$Type, [string]$Value)
            $script:MutationCount++
            throw "mutation must not run"
        }

        $results = @(Set-KitDefenderExclusionState -Exclusions @($script:BlockedDriveRoot, $script:BlockedProcess) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation)

        Assert-KitEqual $results.Count 2
        Assert-KitEqual $results[0].policyStatus "blocked"
        Assert-KitEqual $results[0].action "blocked"
        Assert-KitEqual $results[0].status "failed"
        Assert-KitEqual $results[1].policyStatus "blocked"
        Assert-KitEqual $results[1].action "blocked"
        Assert-KitEqual $results[1].status "manual"
        Assert-KitEqual $script:QueryCount 0
        Assert-KitEqual $script:MutationCount 0
    }

    It "keeps the Defender exclusion report fields stable" {
        $whatIfResult = @(Set-KitDefenderExclusionState -Exclusions @($script:AllowedPath) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery { throw "query must not run" } -DefenderMutation { throw "mutation must not run" } -WhatIf)[0]
        $blockedResult = @(Set-KitDefenderExclusionState -Exclusions @($script:BlockedProcess) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery { throw "query must not run" } -DefenderMutation { throw "mutation must not run" })[0]
        $report = New-KitDefenderExclusionReport -Results @($whatIfResult, $blockedResult) -WhatIf

        Assert-KitEqual $report.reportType "defender-exclusion-policy"
        Assert-KitEqual $report.whatIf $true
        foreach ($summaryField in @("total", "changedCount", "manualCount", "whatIfCount", "blockedByPolicyCount", "failedRequiredCount", "exitCode")) {
            Assert-KitEqual ($report.defenderSummary.PSObject.Properties.Name -contains $summaryField) $true
        }
        Assert-KitEqual $report.defenderSummary.total 2
        Assert-KitEqual $report.defenderSummary.whatIfCount 1
        Assert-KitEqual $report.defenderSummary.manualCount 1
        Assert-KitEqual $report.defenderSummary.blockedByPolicyCount 1
        Assert-KitEqual $report.defenderSummary.exitCode 0

        foreach ($result in @($report.defenderResults)) {
            foreach ($field in @("id", "type", "value", "resolvedValue", "scope", "reason", "policyStatus", "policyReason", "action", "existsBefore", "existsAfter", "required", "failurePolicy", "status")) {
                Assert-KitEqual ($result.PSObject.Properties.Name -contains $field) $true
            }
        }
    }

    It "keeps PR Fast CI on mock, seam, and WhatIf Defender exclusion tests" {
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        foreach ($path in @(
            "tests/pester/DefenderExclusionPolicy.Tests.ps1",
            "tests/pester/DefenderExclusionState.Tests.ps1",
            "tests/pester/DefenderExclusionPostDeploy.Tests.ps1",
            "tests/pester/Issue8DefenderAcceptance.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($path))
        }

        Assert-KitNotMatch $workflow "Add-MpPreference"
        Assert-KitNotMatch $workflow "Remove-MpPreference"
        Assert-KitNotMatch $workflow "Set-MpPreference"
    }

    It "keeps this acceptance test visible to Pester script scope and avoids fragile drive-root literals" {
        $testContent = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\pester\Issue8DefenderAcceptance.Tests.ps1") -Raw -Encoding UTF8

        Assert-KitMatch $testContent "BeforeEach"
        Assert-KitMatch $testContent '\$script:RepoRoot'
        Assert-KitMatch $testContent '\$script:PathMap'
        Assert-KitNotMatch $testContent '["''][A-Za-z]:\\["'']'
    }
}
