#Requires -Version 5.1

. "$PSScriptRoot\Test-KitUserExperienceRestoreSafety.ps1"

function Resolve-KitUserExperienceRestoreRepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
}

function Get-KitUserExperienceStrings {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($InputObject -is [string]) {
            $InputObject
            return
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            foreach ($item in $InputObject) {
                Get-KitUserExperienceStrings -InputObject $item
            }
            return
        }

        if ($InputObject.PSObject -and $InputObject.PSObject.Properties) {
            foreach ($property in $InputObject.PSObject.Properties) {
                Get-KitUserExperienceStrings -InputObject $property.Value
            }
        }
    }
}

function Test-KitUserExperiencePrivatePath {
    param(
        [AllowNull()]
        $InputObject
    )

    $privatePathMatches = @()
    foreach ($value in @($InputObject | Get-KitUserExperienceStrings)) {
        if ($value -match '^[A-Za-z]:\\Users\\[^\\]+' -or $value -match '\\\\192\.168\.1\.37\\') {
            $privatePathMatches += [string]$value
        }
    }

    return @($privatePathMatches)
}

function New-KitUserExperiencePlanResult {
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Scope,

        [Parameter(Mandatory)]
        [ValidateSet("planned", "blocked", "failed")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [int]$PlannedChangeCount = 0,

        [AllowNull()]
        $Details = $null
    )

    [pscustomobject][ordered]@{
        id = $Id
        type = $Type
        scope = $Scope
        status = $Status
        reason = $Reason
        plannedChangeCount = $PlannedChangeCount
        executed = $false
        mutationKind = "none"
        details = $Details
    }
}

function ConvertTo-KitUserExperienceContextResult {
    param(
        [AllowNull()]
        $Context
    )

    $displayVersion = [string](Get-KitUserExperienceValue -InputObject $Context -Name "displayVersion" -DefaultValue "")
    $buildNumber = Get-KitUserExperienceValue -InputObject $Context -Name "buildNumber" -DefaultValue $null
    $status = "passed"
    $reason = "version context is supported"
    $unsupportedVersionCount = 0
    $missingBuildCount = 0

    if ($null -eq $buildNumber -or [string]::IsNullOrWhiteSpace([string]$buildNumber)) {
        $status = "failed"
        $reason = "buildNumber is required"
        $missingBuildCount = 1
    } elseif ($displayVersion -notin @("23H2", "24H2")) {
        $status = "failed"
        $reason = "unsupported Windows displayVersion: $displayVersion"
        $unsupportedVersionCount = 1
    }

    [pscustomobject][ordered]@{
        id = [string](Get-KitUserExperienceValue -InputObject $Context -Name "id" -DefaultValue "")
        productName = [string](Get-KitUserExperienceValue -InputObject $Context -Name "productName" -DefaultValue "")
        displayVersion = $displayVersion
        buildNumber = $buildNumber
        edition = [string](Get-KitUserExperienceValue -InputObject $Context -Name "edition" -DefaultValue "")
        architecture = [string](Get-KitUserExperienceValue -InputObject $Context -Name "architecture" -DefaultValue "")
        scope = [string](Get-KitUserExperienceValue -InputObject $Context -Name "scope" -DefaultValue "")
        status = $status
        reason = $reason
        unsupportedVersionCount = $unsupportedVersionCount
        missingBuildCount = $missingBuildCount
    }
}

function New-KitUserExperienceRestoreReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [string]$RepoRoot,

        [ValidateSet("plan-only", "report-only", "fixture")]
        [string]$Mode = "plan-only",

        [AllowNull()]
        $WindowsContext,

        [AllowNull()]
        $DefaultApps,

        [AllowNull()]
        $StartMenu,

        [AllowNull()]
        $Taskbar,

        [AllowNull()]
        $LocalPrivatePathFixture,

        [switch]$WhatIf
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $manifestErrors = @(Test-KitUserExperienceRestoreSafety -Manifest $Manifest)
    $contexts = @()
    if ($null -ne $WindowsContext) {
        $contexts += ConvertTo-KitUserExperienceContextResult -Context $WindowsContext
    }

    foreach ($manifestContext in @($Manifest.contexts)) {
        $contexts += ConvertTo-KitUserExperienceContextResult -Context $manifestContext
    }

    $plans = @()
    foreach ($errorMessage in $manifestErrors) {
        $plans += New-KitUserExperiencePlanResult -Id "manifest-safety" -Type "safety" -Scope "machine" -Status "failed" -Reason $errorMessage
    }

    foreach ($plan in @($Manifest.plans)) {
        $entrypoint = [string](Get-KitUserExperienceValue -InputObject $plan -Name "entrypoint" -DefaultValue "")
        $status = "planned"
        $reason = "planned only; entrypoint is not invoked"
        if ([string]::IsNullOrWhiteSpace($entrypoint)) {
            $status = "failed"
            $reason = "entrypoint is required"
        } elseif (-not (Test-Path -LiteralPath (Resolve-KitUserExperienceRestoreRepoPath -RepoRoot $RepoRoot -Path $entrypoint))) {
            $status = "failed"
            $reason = "entrypoint is missing"
        }

        $plans += New-KitUserExperiencePlanResult `
            -Id ([string](Get-KitUserExperienceValue -InputObject $plan -Name "id" -DefaultValue "")) `
            -Type ([string](Get-KitUserExperienceValue -InputObject $plan -Name "type" -DefaultValue "")) `
            -Scope ([string](Get-KitUserExperienceValue -InputObject $plan -Name "scope" -DefaultValue "")) `
            -Status $status `
            -Reason $reason
    }

    $missingCapabilityCount = 0
    if ($null -ne $DefaultApps) {
        $associations = @($DefaultApps.associations)
        $defaultStatus = "planned"
        $defaultReason = "default app associations planned only"
        if ([bool](Get-KitUserExperienceValue -InputObject $DefaultApps -Name "mutationRequested" -DefaultValue $false)) {
            $defaultStatus = "blocked"
            $defaultReason = "default app mutation request is blocked"
        }

        $unknown = @($associations | Where-Object { [bool](Get-KitUserExperienceValue -InputObject $_ -Name "knownCapability" -DefaultValue $true) -eq $false })
        if ($unknown.Count -gt 0) {
            $defaultStatus = "blocked"
            $defaultReason = "default app plan references missing capabilities"
            $missingCapabilityCount += $unknown.Count
        }

        $plans += New-KitUserExperiencePlanResult `
            -Id ([string](Get-KitUserExperienceValue -InputObject $DefaultApps -Name "planId" -DefaultValue "default-app-fixture")) `
            -Type "default-apps" `
            -Scope ([string](Get-KitUserExperienceValue -InputObject $DefaultApps -Name "scope" -DefaultValue "default-user")) `
            -Status $defaultStatus `
            -Reason $defaultReason `
            -PlannedChangeCount $associations.Count `
            -Details $DefaultApps
    }

    if ($null -ne $StartMenu) {
        $pins = @($StartMenu.pins)
        $startStatus = "planned"
        $startReason = "Start menu layout planned only"
        if ([bool](Get-KitUserExperienceValue -InputObject $StartMenu -Name "profileWriteRequested" -DefaultValue $false)) {
            $startStatus = "blocked"
            $startReason = "profile write request is blocked"
        }

        if ([bool](Get-KitUserExperienceValue -InputObject $StartMenu -Name "mutationRequested" -DefaultValue $false)) {
            $startStatus = "blocked"
            $startReason = "Start menu mutation request is blocked"
        }

        if ([bool](Get-KitUserExperienceValue -InputObject $StartMenu -Name "unsupportedLayoutVersion" -DefaultValue $false)) {
            $startStatus = "blocked"
            $startReason = "Start menu layout version is unsupported"
        }

        $plans += New-KitUserExperiencePlanResult `
            -Id ([string](Get-KitUserExperienceValue -InputObject $StartMenu -Name "planId" -DefaultValue "start-menu-fixture")) `
            -Type "start-menu" `
            -Scope ([string](Get-KitUserExperienceValue -InputObject $StartMenu -Name "scope" -DefaultValue "current-user")) `
            -Status $startStatus `
            -Reason $startReason `
            -PlannedChangeCount $pins.Count `
            -Details $StartMenu
    }

    if ($null -ne $Taskbar) {
        $pins = @($Taskbar.pins)
        $taskbarStatus = "planned"
        $taskbarReason = "taskbar layout planned only"
        if ([bool](Get-KitUserExperienceValue -InputObject $Taskbar -Name "registryWriteRequested" -DefaultValue $false)) {
            $taskbarStatus = "blocked"
            $taskbarReason = "registry write request is blocked"
        }

        if ([bool](Get-KitUserExperienceValue -InputObject $Taskbar -Name "mutationRequested" -DefaultValue $false)) {
            $taskbarStatus = "blocked"
            $taskbarReason = "taskbar mutation request is blocked"
        }

        $plans += New-KitUserExperiencePlanResult `
            -Id ([string](Get-KitUserExperienceValue -InputObject $Taskbar -Name "planId" -DefaultValue "taskbar-fixture")) `
            -Type "taskbar" `
            -Scope ([string](Get-KitUserExperienceValue -InputObject $Taskbar -Name "scope" -DefaultValue "current-user")) `
            -Status $taskbarStatus `
            -Reason $taskbarReason `
            -PlannedChangeCount $pins.Count `
            -Details $Taskbar
    }

    $localPrivatePathMatches = @()
    if ($null -ne $LocalPrivatePathFixture) {
        $localPrivatePathMatches = @(Test-KitUserExperiencePrivatePath -InputObject $LocalPrivatePathFixture)
        if ($localPrivatePathMatches.Count -gt 0) {
            $plans += New-KitUserExperiencePlanResult `
                -Id "local-private-path-fixture" `
                -Type "safety" `
                -Scope "machine" `
                -Status "blocked" `
                -Reason "local private path is blocked" `
                -Details $LocalPrivatePathFixture
        }
    }

    $blockedCount = @($plans | Where-Object { $_.status -eq "blocked" }).Count
    $failedCount = @($plans | Where-Object { $_.status -eq "failed" }).Count
    $plannedChangeCount = 0
    foreach ($planResult in @($plans)) {
        $plannedChangeCount += [int]$planResult.plannedChangeCount
    }

    $unsupportedVersionCount = 0
    $missingBuildCount = 0
    foreach ($context in @($contexts)) {
        $unsupportedVersionCount += [int]$context.unsupportedVersionCount
        $missingBuildCount += [int]$context.missingBuildCount
    }

    $status = "passed"
    if ($blockedCount -gt 0 -or $failedCount -gt 0 -or $unsupportedVersionCount -gt 0 -or $missingBuildCount -gt 0 -or $missingCapabilityCount -gt 0) {
        $status = "failed"
    }

    [pscustomobject][ordered]@{
        reportType = "user-experience-restore"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        restoreSetId = [string](Get-KitUserExperienceValue -InputObject $Manifest -Name "restoreSetId" -DefaultValue "")
        mode = $Mode
        whatIf = $true
        trueExecution = $false
        status = $status
        summary = [pscustomobject][ordered]@{
            planCount = @($plans).Count
            plannedChangeCount = $plannedChangeCount
            blockedCount = $blockedCount
            failedCount = $failedCount
            registryWriteCount = 0
            profileWriteCount = 0
            defaultAppMutationCount = 0
            startMenuMutationCount = 0
            taskbarMutationCount = 0
            unsupportedVersionCount = $unsupportedVersionCount
            missingBuildCount = $missingBuildCount
            missingCapabilityCount = $missingCapabilityCount
            localPrivatePathCount = $localPrivatePathMatches.Count
        }
        contexts = @($contexts)
        plans = @($plans)
        safety = [pscustomobject][ordered]@{
            registryMutation = $false
            profileMutation = $false
            defaultAppMutation = $false
            startMenuMutation = $false
            taskbarMutation = $false
            networkDownload = $false
        }
    }
}
