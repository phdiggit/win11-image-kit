#Requires -Version 5.1

function ConvertTo-KitUserExperienceCapabilityMatrix {
    param(
        [AllowNull()]
        $InputObject
    )

    $entries = @()
    $unsupportedCapabilityCount = 0
    $manualChecklistCount = 0
    $futureRealVerificationCount = 0

    foreach ($entry in @($InputObject.capabilities)) {
        $supportStatus = [string](Get-KitUserExperienceValue -InputObject $entry -Name "supportStatus" -DefaultValue "")
        $verificationMode = [string](Get-KitUserExperienceValue -InputObject $entry -Name "verificationMode" -DefaultValue "")
        $mutationAllowed = [bool](Get-KitUserExperienceValue -InputObject $entry -Name "mutationAllowed" -DefaultValue $false)
        $status = "planned"
        $reason = "capability is represented as a report-only plan"

        if ($supportStatus -in @("unsupported", "blocked")) {
            $status = "blocked"
            $reason = "capability is unsupported or blocked for this version and scope"
            $unsupportedCapabilityCount++
        }

        if ($mutationAllowed) {
            $status = "blocked"
            $reason = "capability matrix cannot allow mutation in the Issue 18 stage"
        }

        if ($verificationMode -eq "manual-checklist") {
            $manualChecklistCount++
        }

        if ($verificationMode -eq "future-real-verification") {
            $futureRealVerificationCount++
        }

        $entries += [pscustomobject][ordered]@{
            id = [string](Get-KitUserExperienceValue -InputObject $entry -Name "id" -DefaultValue "")
            displayVersion = [string](Get-KitUserExperienceValue -InputObject $entry -Name "displayVersion" -DefaultValue "")
            buildMin = [int](Get-KitUserExperienceValue -InputObject $entry -Name "buildMin" -DefaultValue 0)
            buildMax = [int](Get-KitUserExperienceValue -InputObject $entry -Name "buildMax" -DefaultValue 0)
            scope = [string](Get-KitUserExperienceValue -InputObject $entry -Name "scope" -DefaultValue "")
            feature = [string](Get-KitUserExperienceValue -InputObject $entry -Name "feature" -DefaultValue "")
            supportStatus = $supportStatus
            verificationMode = $verificationMode
            mutationAllowed = $mutationAllowed
            status = $status
            reason = $reason
            executed = $false
        }
    }

    [pscustomobject][ordered]@{
        reportType = "ux-capability-matrix"
        schemaVersion = [int](Get-KitUserExperienceValue -InputObject $InputObject -Name "schemaVersion" -DefaultValue 1)
        matrixId = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "matrixId" -DefaultValue "")
        status = $(if ($unsupportedCapabilityCount -gt 0 -or @($entries | Where-Object { $_.status -eq "blocked" }).Count -gt 0) { "failed" } else { "passed" })
        unsupportedCapabilityCount = $unsupportedCapabilityCount
        manualChecklistCount = $manualChecklistCount
        futureRealVerificationCount = $futureRealVerificationCount
        capabilities = @($entries)
    }
}
