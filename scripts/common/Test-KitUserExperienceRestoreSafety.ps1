#Requires -Version 5.1

function Get-KitUserExperienceValue {
    param(
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }

    if ($null -ne $InputObject.PSObject -and $null -ne $InputObject.PSObject.Properties[$Name]) {
        return $InputObject.PSObject.Properties[$Name].Value
    }

    return $DefaultValue
}

function Test-KitUserExperienceRestoreSafety {
    param(
        [Parameter(Mandatory)]
        $Manifest
    )

    $errors = @()

    if ([string](Get-KitUserExperienceValue -InputObject $Manifest -Name "defaultMode" -DefaultValue "") -notin @("plan-only", "report-only", "fixture")) {
        $errors += "defaultMode must be plan-only, report-only, or fixture"
    }

    foreach ($name in @(
        "allowProfileMutation",
        "allowRegistryMutation",
        "allowStartMenuMutation",
        "allowTaskbarMutation",
        "allowDefaultAppMutation",
        "allowNetworkDownload"
    )) {
        if ([bool](Get-KitUserExperienceValue -InputObject $Manifest -Name $name -DefaultValue $true)) {
            $errors += "$name must be false"
        }
    }

    foreach ($plan in @($Manifest.plans)) {
        if ([string](Get-KitUserExperienceValue -InputObject $plan -Name "mode" -DefaultValue "") -notin @("plan-only", "report-only", "fixture")) {
            $errors += "plan mode must be plan-only, report-only, or fixture"
        }

        if ([string](Get-KitUserExperienceValue -InputObject $plan -Name "mutationKind" -DefaultValue "") -ne "none") {
            $errors += "plan mutationKind must be none"
        }
    }

    return @($errors)
}
