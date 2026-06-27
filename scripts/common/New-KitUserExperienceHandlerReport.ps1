#Requires -Version 5.1

. "$PSScriptRoot\New-KitUserExperienceRestoreReport.ps1"
. "$PSScriptRoot\ConvertTo-KitUserExperienceHandlerPlan.ps1"
. "$PSScriptRoot\New-KitUserExperienceManualChecklist.ps1"

function New-KitUserExperienceHandlerReport {
    [CmdletBinding()]
    param(
        [ValidateSet("plan-only", "report-only", "fixture")]
        [string]$Mode = "plan-only",

        [ValidateSet("default-user", "current-user", "offline-image", "machine")]
        [string]$Scope = "default-user",

        [switch]$RequestedApply,

        [AllowNull()]$DefaultApps,
        [AllowNull()]$StartMenu,
        [AllowNull()]$Taskbar,
        [AllowNull()]$TemplateSources = @(),
        [AllowNull()]$ScopeMapping = $null,
        [AllowNull()]$LegacyItems = @(),
        [AllowNull()]$UserExperienceResults = @()
    )

    $handlers = @()
    if ($null -ne $DefaultApps) { $handlers += ConvertTo-KitDefaultAppAssociationPlan -InputObject $DefaultApps }
    if ($null -ne $StartMenu) { $handlers += ConvertTo-KitStartMenuLayoutPlan -InputObject $StartMenu }
    if ($null -ne $Taskbar) { $handlers += ConvertTo-KitTaskbarPlan -InputObject $Taskbar }

    if ($RequestedApply) {
        $handlers += [pscustomobject][ordered]@{
            handlerId = "requested-apply"
            handlerType = "verification"
            scope = $Scope
            mode = $Mode
            source = "request"
            templateMetadataId = ""
            supportStatus = "blocked"
            verificationMode = "manual-checklist"
            requestedApply = $true
            executed = $false
            status = "blocked"
            reason = "Apply or Execute is blocked in the Issue 18 report-only stage"
            plannedChangeCount = 0
            missingCapabilityCount = 0
            requestedApplyBlockedCount = 1
            exitCodeOnlySuccessClaimCount = 0
            userConfigurationFalseClaimCount = 0
            details = $null
        }
    }

    $manualChecklist = @(New-KitUserExperienceManualChecklist -Handlers $handlers)
    $blockedHandlerCount = @($handlers | Where-Object { $_.status -eq "blocked" }).Count
    $failedHandlerCount = @($handlers | Where-Object { $_.status -eq "failed" }).Count
    $manualHandlerCount = @($handlers | Where-Object { $_.status -eq "manual" }).Count
    $plannedHandlerCount = @($handlers | Where-Object { $_.status -eq "planned" }).Count
    $status = if ($blockedHandlerCount -gt 0 -or $failedHandlerCount -gt 0) { "blocked" } else { "planned" }

    [pscustomobject][ordered]@{
        reportType = "restore-user-experience"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        mode = $Mode
        whatIf = $true
        trueExecution = $false
        requestedApply = [bool]$RequestedApply
        status = $status
        scope = $Scope
        handlers = @($handlers)
        manualChecklist = $manualChecklist
        templateSources = @($TemplateSources)
        scopeMapping = $ScopeMapping
        summary = [pscustomobject][ordered]@{
            plannedHandlerCount = $plannedHandlerCount
            blockedHandlerCount = $blockedHandlerCount
            failedHandlerCount = $failedHandlerCount
            manualHandlerCount = $manualHandlerCount
            futureVerificationHandlerCount = @($handlers | Where-Object { $_.verificationMode -eq "future-real-verification" }).Count
            defaultUserHandlerCount = @($handlers | Where-Object { $_.scope -eq "default-user" }).Count
            currentUserHandlerCount = @($handlers | Where-Object { $_.scope -eq "current-user" }).Count
            offlineImageHandlerCount = @($handlers | Where-Object { $_.scope -eq "offline-image" }).Count
            templateSourceCount = @($TemplateSources).Count
            handlerExecutionCount = 0
            registryWriteCount = 0
            profileWriteCount = 0
            defaultAppMutationCount = 0
            startMenuMutationCount = 0
            taskbarMutationCount = 0
            requestedApplyBlockedCount = @($handlers | Where-Object { [int]$_.requestedApplyBlockedCount -gt 0 }).Count
            exitCodeOnlySuccessClaimCount = @($handlers | Where-Object { [int]$_.exitCodeOnlySuccessClaimCount -gt 0 }).Count
            userConfigurationFalseClaimCount = @($handlers | Where-Object { [int]$_.userConfigurationFalseClaimCount -gt 0 }).Count
            manualChecklistCount = @($manualChecklist).Count
            missingCapabilityCount = @($handlers | Where-Object { [int]$_.missingCapabilityCount -gt 0 }).Count
        }
        items = @($LegacyItems)
        userExperienceResults = @($UserExperienceResults)
    }
}
