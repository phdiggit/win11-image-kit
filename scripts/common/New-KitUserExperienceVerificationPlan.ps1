#Requires -Version 5.1

function New-KitUserExperienceVerificationPlan {
    param(
        [AllowNull()]
        $InputObject
    )

    $status = "planned"
    $reason = "verification is planned only"
    $verificationFailureCount = 0
    $exitCodeOnlySuccessClaimCount = 0
    $userConfigurationFalseClaimCount = 0
    $manualChecklistCount = 0
    $futureRealVerificationCount = 0
    $evidenceType = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "evidenceType" -DefaultValue "")
    $successSignal = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "successSignal" -DefaultValue "")

    if ([bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "commandExitCodeSufficient" -DefaultValue $false)) {
        $status = "blocked"
        $reason = "command exit code alone cannot confirm UX restore"
        $exitCodeOnlySuccessClaimCount++
        $verificationFailureCount++
    }

    if ([bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "userConfigurationConfirmed" -DefaultValue $false)) {
        $status = "blocked"
        $reason = "user configuration cannot be confirmed without future real verification"
        $userConfigurationFalseClaimCount++
        $verificationFailureCount++
    }

    if ($evidenceType -eq "manual-checklist") {
        $manualChecklistCount++
    }

    if ($successSignal -eq "future-real-verification-required") {
        $futureRealVerificationCount++
    }

    [pscustomobject][ordered]@{
        reportType = "ux-verification-plan"
        schemaVersion = [int](Get-KitUserExperienceValue -InputObject $InputObject -Name "schemaVersion" -DefaultValue 1)
        verificationId = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "verificationId" -DefaultValue "")
        scope = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "scope" -DefaultValue "")
        feature = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "feature" -DefaultValue "")
        currentStage = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "currentStage" -DefaultValue "")
        evidenceType = $evidenceType
        successSignal = $successSignal
        commandExitCodeSufficient = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "commandExitCodeSufficient" -DefaultValue $false)
        userConfigurationConfirmed = [bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "userConfigurationConfirmed" -DefaultValue $false)
        trueExecution = $false
        status = $status
        reason = $reason
        verificationFailureCount = $verificationFailureCount
        exitCodeOnlySuccessClaimCount = $exitCodeOnlySuccessClaimCount
        userConfigurationFalseClaimCount = $userConfigurationFalseClaimCount
        manualChecklistCount = $manualChecklistCount
        futureRealVerificationCount = $futureRealVerificationCount
        executed = $false
    }
}
