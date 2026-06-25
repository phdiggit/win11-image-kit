$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Sysprep AppX readiness report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitSysprepAppxReadiness.ps1")

        $script:Policy = [pscustomobject]@{
            mode = "audit"
            failurePolicy = "fail"
            rules = [pscustomobject]@{
                blockUserInstalledNotProvisioned = $true
                blockProvisionedInstalledMismatch = $true
                blockQueryFailure = $true
                ignoreFrameworkPackages = $true
                ignoreResourcePackages = $true
                ignoreNonRemovableSystemPackages = $true
            }
            allowFamilies = @()
            manualFamilies = @()
        }
    }

    It "summarizes finding counts correctly" {
        $findings = @(
            [pscustomobject]@{ packageFamilyName = "Blocking_abc"; status = "blocking"; recommendedAction = "fix"; reason = "user-installed-not-provisioned" },
            [pscustomobject]@{ packageFamilyName = "Manual_abc"; status = "manual"; recommendedAction = "review"; reason = "manual-family-policy" },
            [pscustomobject]@{ packageFamilyName = "Allowed_abc"; status = "allowed"; recommendedAction = "verify"; reason = "allow-family-policy" },
            [pscustomobject]@{ packageFamilyName = "Ignored_abc"; status = "ignored"; recommendedAction = "audit"; reason = "framework-package-ignored" }
        )

        $report = New-KitSysprepAppxReadinessReport -Policy $script:Policy -Findings $findings -QueryErrors @([pscustomobject]@{ message = "failed" })

        Assert-KitEqual $report.summary.blockingCount 1
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual $report.summary.allowedCount 1
        Assert-KitEqual $report.summary.ignoredCount 1
        Assert-KitEqual $report.summary.queryErrorCount 1
        Assert-KitEqual $report.exitCode 1
    }

    It "keeps required report and finding fields serializable" {
        $finding = [pscustomobject]@{
            packageFamilyName = "Blocking_abc"
            packageFullName = "Blocking_1.0.0.0_x64__abc"
            status = "blocking"
            reason = "user-installed-not-provisioned"
            evidence = [pscustomobject]@{ version = "1.0.0.0" }
            recommendedAction = "Review manually."
        }

        $report = New-KitSysprepAppxReadinessReport -Policy $script:Policy -PolicyPath "manifests/sysprep-appx-gate.json" -Findings @($finding)
        $roundTrip = $report | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $reportedFinding = @($roundTrip.findings)[0]

        Assert-KitEqual $roundTrip.reportType "sysprep-appx-readiness"
        Assert-KitEqual $roundTrip.policyPath "manifests/sysprep-appx-gate.json"
        Assert-KitEqual $reportedFinding.packageFamilyName "Blocking_abc"
        Assert-KitEqual $reportedFinding.status "blocking"
        Assert-KitNotNullOrEmpty $reportedFinding.evidence
        Assert-KitNotNullOrEmpty $reportedFinding.recommendedAction
    }

    It "does not drop blocking findings from the report" {
        $findings = @(
            [pscustomobject]@{ packageFamilyName = "One_abc"; status = "blocking"; recommendedAction = "fix"; reason = "one" },
            [pscustomobject]@{ packageFamilyName = "Two_abc"; status = "blocking"; recommendedAction = "fix"; reason = "two" }
        )

        $report = New-KitSysprepAppxReadinessReport -Policy $script:Policy -Findings $findings

        Assert-KitEqual @($report.findings | Where-Object { $_.status -eq "blocking" }).Count 2
        Assert-KitEqual $report.summary.blockingCount 2
    }

    It "writes CLI reports only to an explicit temp path when fixture inventory is supplied" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-sysprep-appx-report-{0}" -f ([guid]::NewGuid().ToString("N")))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $inventoryPath = Join-Path $tempRoot "inventory.json"
        $reportPath = Join-Path $tempRoot "report.json"

        try {
            ([ordered]@{
                generatedAt = "2026-06-25T00:00:00Z"
                provisionedPackages = @()
                installedPackages = @()
                queryErrors = @()
                source = "fixture"
            }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\validate\Test-SysprepReadiness.ps1") -InventoryPath $inventoryPath -ReportPath $reportPath -WhatIf | Out-Null
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $LASTEXITCODE 0
            Assert-KitEqual $report.reportType "sysprep-appx-readiness"
            Assert-KitEqual $report.whatIf $true
        } finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
