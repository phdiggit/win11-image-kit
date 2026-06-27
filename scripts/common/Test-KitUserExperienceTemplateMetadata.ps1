#Requires -Version 5.1

function Test-KitUserExperienceTemplateMetadata {
    param(
        [AllowNull()]
        $InputObject
    )

    $status = "passed"
    $reason = "template metadata is compatible with the planned target"
    $failureCount = 0
    $scopeMismatchCount = 0
    $missingCapabilityCount = 0
    $localPrivatePathCount = 0
    $sourceWindows = Get-KitUserExperienceValue -InputObject $InputObject -Name "sourceWindows"
    $sourceBuild = Get-KitUserExperienceValue -InputObject $sourceWindows -Name "buildNumber" -DefaultValue $null
    $displayVersion = [string](Get-KitUserExperienceValue -InputObject $sourceWindows -Name "displayVersion" -DefaultValue "")
    $targetScope = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "targetScope" -DefaultValue "")
    $expectedScope = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "expectedScope" -DefaultValue $targetScope)
    $templateType = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "templateType" -DefaultValue "")
    $expectedTemplateType = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "expectedTemplateType" -DefaultValue $templateType)

    if ($null -eq $sourceBuild -or [string]::IsNullOrWhiteSpace([string]$sourceBuild)) {
        $status = "failed"
        $reason = "sourceWindows.buildNumber is required"
        $failureCount++
    } elseif ($displayVersion -notin @("23H2", "24H2")) {
        $status = "failed"
        $reason = "template source Windows version is unsupported"
        $failureCount++
    }

    if ($targetScope -ne $expectedScope) {
        $status = "failed"
        $reason = "target scope does not match the expected scope"
        $scopeMismatchCount++
        $failureCount++
    }

    if ($templateType -ne $expectedTemplateType) {
        $status = "failed"
        $reason = "template type does not match the expected type"
        $failureCount++
    }

    foreach ($app in @($InputObject.targetApps)) {
        if ([bool](Get-KitUserExperienceValue -InputObject $app -Name "required" -DefaultValue $false) -and -not [bool](Get-KitUserExperienceValue -InputObject $app -Name "knownCapability" -DefaultValue $true)) {
            $status = "failed"
            $reason = "required target app capability is missing"
            $missingCapabilityCount++
            $failureCount++
        }

        if ([bool](Get-KitUserExperienceValue -InputObject $app -Name "unknownProgId" -DefaultValue $false)) {
            $status = "failed"
            $reason = "target app references an unknown ProgId"
            $missingCapabilityCount++
            $failureCount++
        }
    }

    $privatePaths = @(Test-KitUserExperiencePrivatePath -InputObject $InputObject)
    if ($privatePaths.Count -gt 0) {
        $status = "failed"
        $reason = "template metadata references a local private path"
        $localPrivatePathCount = $privatePaths.Count
        $failureCount += $privatePaths.Count
    }

    [pscustomobject][ordered]@{
        reportType = "ux-template-metadata"
        schemaVersion = [int](Get-KitUserExperienceValue -InputObject $InputObject -Name "schemaVersion" -DefaultValue 1)
        templateId = [string](Get-KitUserExperienceValue -InputObject $InputObject -Name "templateId" -DefaultValue "")
        templateType = $templateType
        targetScope = $targetScope
        status = $status
        reason = $reason
        failureCount = $failureCount
        scopeMismatchCount = $scopeMismatchCount
        missingCapabilityCount = $missingCapabilityCount
        localPrivatePathCount = $localPrivatePathCount
        sourceWindows = $sourceWindows
        targetApps = @($InputObject.targetApps)
        executed = $false
    }
}
