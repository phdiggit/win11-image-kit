#Requires -Version 5.1

function Test-KitControlledExecutionAuthorization {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{
            status = "blocked"
            reason = "authorization input is missing"
            failureCount = 1
            executeRequestBlockedCount = 0
            requestedMode = "plan-only"
            executeRequested = $false
            allowTrueExecution = $false
            trueExecutionAllowed = $false
        }
    }

    $reasons = @()
    $executeRequestBlockedCount = 0
    $requestedMode = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "requestedMode" -DefaultValue "plan-only")
    $executeRequested = [bool](Get-KitControlledExecutionValue -InputObject $InputObject -Name "executeRequested" -DefaultValue $false)
    $allowTrueExecution = [bool](Get-KitControlledExecutionValue -InputObject $InputObject -Name "allowTrueExecution" -DefaultValue $false)
    $trueExecutionAllowed = [bool](Get-KitControlledExecutionValue -InputObject $InputObject -Name "trueExecutionAllowed" -DefaultValue $false)
    $tokenStatus = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "confirmationTokenStatus" -DefaultValue "")
    $diskStatus = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "diskIdentityStatus" -DefaultValue "")
    $wimStatus = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "wimValidationStatus" -DefaultValue "")
    $sourceRunId = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "sourceRunId" -DefaultValue "")
    $expectedSourceRunId = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "expectedSourceRunId" -DefaultValue $sourceRunId)

    if ($allowTrueExecution) {
        $reasons += "allowTrueExecution must remain false"
    }

    if ($trueExecutionAllowed) {
        $reasons += "trueExecutionAllowed must remain false"
    }

    if ($executeRequested -or $requestedMode -eq "execute") {
        $executeRequestBlockedCount = 1
        $reasons += "true execution is not implemented/enabled in Issue #17 current stage"
    }

    if ($tokenStatus -ne "matched") {
        $reasons += "confirmation token must be matched"
    }

    if ($diskStatus -ne "matched") {
        $reasons += "disk identity must be matched"
    }

    if ($wimStatus -ne "matched") {
        $reasons += "WIM validation must be matched"
    }

    if ([string]::IsNullOrWhiteSpace($sourceRunId)) {
        $reasons += "sourceRunId is required"
    } elseif (-not [string]::IsNullOrWhiteSpace($expectedSourceRunId) -and $sourceRunId -ne $expectedSourceRunId) {
        $reasons += "sourceRunId is stale or mismatched"
    }

    $status = "planned"
    if ($reasons.Count -gt 0) {
        $status = "blocked"
    }

    [pscustomobject][ordered]@{
        status = $status
        reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "authorization planned; true execution remains disabled" }
        failureCount = $reasons.Count
        executeRequestBlockedCount = $executeRequestBlockedCount
        requestedMode = $requestedMode
        executeRequested = $executeRequested
        allowTrueExecution = $allowTrueExecution
        targetDiskNumber = [int](Get-KitControlledExecutionValue -InputObject $InputObject -Name "targetDiskNumber" -DefaultValue -1)
        targetDiskSerial = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "targetDiskSerial" -DefaultValue "")
        confirmationTokenStatus = $tokenStatus
        diskIdentityStatus = $diskStatus
        wimValidationStatus = $wimStatus
        sourceRunId = $sourceRunId
        expectedSourceRunId = $expectedSourceRunId
        authorizationStatus = $status
        trueExecutionAllowed = $false
    }
}
