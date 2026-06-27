#Requires -Version 5.1

function Test-KitUserExperienceScopeSemantics {
    param(
        [AllowNull()]
        $InputObject
    )

    $status = "passed"
    $reason = "scope semantics remain distinct and report-only"
    $scopeMismatchCount = 0

    if ([bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "defaultProfileClaimsCurrentUser" -DefaultValue $false)) {
        $status = "failed"
        $reason = "Default Profile changes cannot claim current-user mutation"
        $scopeMismatchCount++
    }

    if ([bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "offlineImageClaimsCurrentMachine" -DefaultValue $false)) {
        $status = "failed"
        $reason = "offline-image scope cannot claim current running machine mutation"
        $scopeMismatchCount++
    }

    if ([bool](Get-KitUserExperienceValue -InputObject $InputObject -Name "scopeMismatch" -DefaultValue $false)) {
        $status = "failed"
        $reason = "fixture declares a scope mismatch"
        $scopeMismatchCount++
    }

    [pscustomobject][ordered]@{
        reportType = "ux-scope-semantics"
        schemaVersion = [int](Get-KitUserExperienceValue -InputObject $InputObject -Name "schemaVersion" -DefaultValue 1)
        semanticsId = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "semanticsId" -DefaultValue "")
        sourceScope = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "sourceScope" -DefaultValue "")
        targetScope = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "targetScope" -DefaultValue "")
        status = $status
        reason = $reason
        scopeMismatchCount = $scopeMismatchCount
        userConfigurationConfirmed = $false
        executed = $false
    }
}
