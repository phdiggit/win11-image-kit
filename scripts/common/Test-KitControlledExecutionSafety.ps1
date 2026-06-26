#Requires -Version 5.1

function Get-KitControlledExecutionValue {
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

function Test-KitControlledExecutionSafety {
    param(
        [Parameter(Mandatory)]
        $Manifest
    )

    $errors = @()

    if ([bool](Get-KitControlledExecutionValue -InputObject $Manifest -Name "allowTrueExecution" -DefaultValue $true)) {
        $errors += "allowTrueExecution must be false in the Issue 17 baseline"
    }

    if ([string](Get-KitControlledExecutionValue -InputObject $Manifest -Name "defaultMode" -DefaultValue "") -notin @("dry-run", "what-if", "plan-only")) {
        $errors += "defaultMode must be dry-run, what-if, or plan-only"
    }

    $safety = Get-KitControlledExecutionValue -InputObject $Manifest -Name "safety"
    foreach ($name in @(
        "trueExecutionDefault",
        "allowDiskMutation",
        "allowRegistryMutation",
        "allowNetworkDownload",
        "allowServiceMutation",
        "allowProfileMutation",
        "allowHiveMutation"
    )) {
        if ([bool](Get-KitControlledExecutionValue -InputObject $safety -Name $name -DefaultValue $true)) {
            $errors += "safety.$name must be false"
        }
    }

    return @($errors)
}

