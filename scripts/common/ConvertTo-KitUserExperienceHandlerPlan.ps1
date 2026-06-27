#Requires -Version 5.1

function New-KitUserExperienceHandlerPlan {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [ValidateSet("default-apps", "start-menu", "taskbar")]
        [string]$HandlerType
    )

    $handlerId = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "handlerId" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($handlerId)) {
        $handlerId = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "planId" -DefaultValue "$HandlerType-handler")
    }

    $scope = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "scope" -DefaultValue "current-user")
    $supportStatus = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "supportStatus" -DefaultValue "planned-supported")
    $verificationMode = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "verificationMode" -DefaultValue "future-real-verification")
    $templateMetadataId = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "templateMetadataId" -DefaultValue "")
    $requestedApply = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "requestedApply" -DefaultValue $false)
    $mutationRequested = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "mutationRequested" -DefaultValue $false)
    $profileWriteRequested = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "profileWriteRequested" -DefaultValue $false)
    $registryWriteRequested = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "registryWriteRequested" -DefaultValue $false)
    $claimsCurrentUserConfigured = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "claimsCurrentUserConfigured" -DefaultValue $false)
    $commandExitCodeSufficient = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "commandExitCodeSufficient" -DefaultValue $false)

    $status = "planned"
    $reason = "$HandlerType handler is report-only"
    $plannedChangeCount = 0
    $missingCapabilityCount = 0
    $requestedApplyBlockedCount = 0
    $exitCodeOnlySuccessClaimCount = 0
    $userConfigurationFalseClaimCount = 0

    if ($HandlerType -eq "default-apps") {
        $plannedChangeCount = @($InputObject.associations).Count
        $missingCapabilityCount = @($InputObject.associations | Where-Object {
            [bool](Get-KitUserExperienceValue -InputObject $_ -Name "knownCapability" -DefaultValue $true) -eq $false
        }).Count
        if ($scope -eq "current-user") {
            $status = "manual"
            $reason = "current-user default app restore requires future manual or real verification"
        }
    } elseif ($HandlerType -eq "start-menu") {
        $plannedChangeCount = @($InputObject.pins).Count
        if ($scope -eq "current-user") {
            $status = "manual"
            $reason = "current-user Start menu restore is a manual checklist in the Issue 18 stage"
        }
    } elseif ($HandlerType -eq "taskbar") {
        $plannedChangeCount = @($InputObject.pins).Count
        $status = "manual"
        $reason = "taskbar restore is a manual checklist in the Issue 18 stage"
    }

    if ($requestedApply -or $mutationRequested) {
        $status = "blocked"
        $reason = "requested apply or mutation is blocked in the Issue 18 report-only stage"
        $requestedApplyBlockedCount = 1
    }

    if ($profileWriteRequested) {
        $status = "blocked"
        $reason = "profile write request is blocked"
    }

    if ($registryWriteRequested) {
        $status = "blocked"
        $reason = "registry write request is blocked"
    }

    if ($missingCapabilityCount -gt 0) {
        $status = "blocked"
        $reason = "handler references missing required app or ProgId capability"
    }

    if ($claimsCurrentUserConfigured) {
        $status = "blocked"
        $reason = "handler cannot claim current user configuration without supported real verification"
        $userConfigurationFalseClaimCount = 1
    }

    if ($commandExitCodeSufficient) {
        $status = "blocked"
        $reason = "command exit code alone cannot confirm UX restore"
        $exitCodeOnlySuccessClaimCount = 1
    }

    [pscustomobject][ordered]@{
        handlerId = $handlerId
        handlerType = $HandlerType
        scope = $scope
        mode = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "mode" -DefaultValue "report-only")
        source = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "source" -DefaultValue "fixture")
        templateMetadataId = $templateMetadataId
        supportStatus = $supportStatus
        verificationMode = $verificationMode
        requestedApply = $requestedApply
        executed = $false
        status = $status
        reason = $reason
        plannedChangeCount = $plannedChangeCount
        missingCapabilityCount = $missingCapabilityCount
        requestedApplyBlockedCount = $requestedApplyBlockedCount
        exitCodeOnlySuccessClaimCount = $exitCodeOnlySuccessClaimCount
        userConfigurationFalseClaimCount = $userConfigurationFalseClaimCount
        details = $InputObject
    }
}

function ConvertTo-KitDefaultAppAssociationPlan {
    param([AllowNull()]$InputObject)
    if ($null -eq $InputObject) { return @() }
    return New-KitUserExperienceHandlerPlan -InputObject $InputObject -HandlerType "default-apps"
}

function ConvertTo-KitStartMenuLayoutPlan {
    param([AllowNull()]$InputObject)
    if ($null -eq $InputObject) { return @() }
    return New-KitUserExperienceHandlerPlan -InputObject $InputObject -HandlerType "start-menu"
}

function ConvertTo-KitTaskbarPlan {
    param([AllowNull()]$InputObject)
    if ($null -eq $InputObject) { return @() }
    return New-KitUserExperienceHandlerPlan -InputObject $InputObject -HandlerType "taskbar"
}
