$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Sysprep AppX readiness gate" {
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

        $script:NewPackage = {
            param(
                [string]$Family = "Contoso.App_abc123",
                [string]$Source = "installed",
                [string]$Version = "1.0.0.0",
                [bool]$IsFramework = $false,
                [bool]$IsResourcePackage = $false,
                [bool]$NonRemovable = $false
            )

            [pscustomobject]@{
                name = ($Family -replace "_.*$", "")
                packageName = ("{0}_{1}_x64__abc123" -f ($Family -replace "_.*$", ""), $Version)
                packageFullName = ("{0}_{1}_x64__abc123" -f ($Family -replace "_.*$", ""), $Version)
                packageFamilyName = $Family
                version = $Version
                architecture = "x64"
                userSid = "S-1-5-21-100"
                isFramework = $IsFramework
                isResourcePackage = $IsResourcePackage
                nonRemovable = $NonRemovable
                source = $Source
            }
        }

        $script:NewInventory = {
            param(
                $Provisioned = @(),
                $Installed = @(),
                $QueryErrors = @()
            )

            [pscustomobject]@{
                generatedAt = "2026-06-25T00:00:00Z"
                provisionedPackages = @($Provisioned)
                installedPackages = @($Installed)
                queryErrors = @($QueryErrors)
                source = "fixture"
            }
        }
    }

    It "blocks installed families that are not provisioned" {
        $inventory = & $script:NewInventory -Installed @((& $script:NewPackage -Family "Contoso.UserOnly_abc123" -Source "installed"))

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $script:Policy

        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.exitCode 1
        Assert-KitEqual $report.summary.blockingCount 1
        Assert-KitEqual @($report.findings)[0].reason "user-installed-not-provisioned"
    }

    It "records allowed families with policy reasons" {
        $policy = $script:Policy
        $policy.allowFamilies = @([pscustomobject]@{ familyName = "Contoso.Allowed_abc123"; reason = "Known allowed package" })
        $inventory = & $script:NewInventory -Installed @((& $script:NewPackage -Family "Contoso.Allowed_abc123" -Source "installed"))

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $policy

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.summary.allowedCount 1
        Assert-KitMatch @($report.findings)[0].policyReason "Known allowed"
    }

    It "records manual families without pretending success" {
        $policy = $script:Policy
        $policy.manualFamilies = @([pscustomobject]@{ familyName = "Contoso.Manual_abc123"; reason = "Needs maintainer review" })
        $inventory = & $script:NewInventory -Installed @((& $script:NewPackage -Family "Contoso.Manual_abc123" -Source "installed"))

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $policy

        Assert-KitEqual $report.status "manual"
        Assert-KitEqual $report.exitCode 0
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitMatch @($report.findings)[0].recommendedAction "VM snapshot"
    }

    It "can ignore framework resource and non-removable packages by policy" {
        $inventory = & $script:NewInventory -Installed @(
            (& $script:NewPackage -Family "Contoso.Framework_abc123" -Source "installed" -IsFramework $true),
            (& $script:NewPackage -Family "Contoso.Resource_abc123" -Source "installed" -IsResourcePackage $true),
            (& $script:NewPackage -Family "Contoso.System_abc123" -Source "installed" -NonRemovable $true)
        )

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $script:Policy

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.summary.ignoredCount 3
        Assert-KitEqual $report.summary.blockingCount 0
    }

    It "fails query failures when blockQueryFailure and failurePolicy fail are active" {
        $inventory = & $script:NewInventory -QueryErrors @([pscustomobject]@{ source = "installed"; command = "Get-AppxPackage -AllUsers"; message = "access denied" })

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $script:Policy

        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.exitCode 1
        Assert-KitEqual $report.summary.queryErrorCount 1
        Assert-KitEqual @($report.findings)[0].reason "appx-query-failed"
    }

    It "maps failurePolicy manual to manual findings and exitCode zero" {
        $policy = $script:Policy
        $policy.failurePolicy = "manual"
        $inventory = & $script:NewInventory -Installed @((& $script:NewPackage -Family "Contoso.UserOnly_abc123" -Source "installed"))

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $policy

        Assert-KitEqual $report.status "manual"
        Assert-KitEqual $report.exitCode 0
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual $report.summary.blockingCount 0
    }

    It "marks WhatIf reports without mutation hooks" {
        $inventory = & $script:NewInventory -Installed @((& $script:NewPackage -Family "Contoso.UserOnly_abc123" -Source "installed"))

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $script:Policy -WhatIf

        Assert-KitEqual $report.whatIf $true
        Assert-KitEqual $report.summary.blockingCount 1
    }

    It "passes when provisioned and installed families are consistent" {
        $provisioned = & $script:NewPackage -Family "Contoso.Match_abc123" -Source "provisioned"
        $installed = & $script:NewPackage -Family "Contoso.Match_abc123" -Source "installed"
        $inventory = & $script:NewInventory -Provisioned @($provisioned) -Installed @($installed)

        $report = Test-KitSysprepAppxReadiness -Inventory $inventory -Policy $script:Policy

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.exitCode 0
        Assert-KitEqual @($report.findings).Count 0
    }
}
